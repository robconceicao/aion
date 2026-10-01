"""Network replay, concurrency and recovery; no real AI, auth or database calls."""
import asyncio
import threading
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock
from fastapi import FastAPI, HTTPException
import httpx
from app.services.dream_commands import execute_dream_command


class Database:
    def __init__(self):
        self.rows = {}
        self.dreams = {}
        self.lock = threading.Lock()
        self.drop_complete = 0

    def rpc(self, name, args):
        def execute():
            with self.lock:
                key = (args['p_user_id'], args['p_command_id'])
                row = self.rows.get(key)
                if name == 'claim_dream_command':
                    if row is None or row['state'] == 'failed':
                        row = self.rows[key] = {**args, 'state': 'running'}
                    if row['p_hash'] != args['p_hash']:
                        data = {'state': 'conflict'}
                    elif row['state'] == 'running' and row['p_lease'] == args['p_lease']:
                        data = {'state': 'claimed'}
                    else:
                        data = dict(row)
                elif name == 'checkpoint_dream_command':
                    assert row['p_lease'] == args['p_lease']
                    row.update(state='generated', dream=args['p_dream'], response=args['p_response'])
                    data = None
                elif name == 'fail_dream_command':
                    row['state'] = 'failed'
                    data = None
                else:
                    assert row['dream']['id'] in self.dreams
                    row['state'] = 'complete'
                    if self.drop_complete:
                        self.drop_complete -= 1
                        raise ConnectionError('response lost after commit')
                    data = row['response']
                return SimpleNamespace(data=data)
        return SimpleNamespace(execute=execute)


class CommandsTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.db = Database()
        self.generate = AsyncMock(return_value=({'id': 'dream-1', 'user_id': 'alice'}, {'id': 'dream-1', 'narrative': 'dual result'}))
        async def persist(row):
            self.db.dreams[row['id']] = row
        self.persist = AsyncMock(side_effect=persist)

    async def run_command(self, owner='alice', payload=None):
        return await execute_dream_command(self.db, owner, 'command-1', payload or {'text': 'same dream'}, self.generate, self.persist)

    async def test_http_response_lost_replay_does_not_generate_again(self):
        app = FastAPI()
        @app.post('/dream')
        async def dream():
            return await self.run_command()
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url='http://test') as client:
            self.db.drop_complete = 3
            self.assertEqual((await client.post('/dream')).status_code, 503)
            recovered = await client.post('/dream')
            self.assertEqual(recovered.status_code, 200)
            self.assertEqual(recovered.json()['id'], 'dream-1')
        self.assertEqual(self.generate.await_count, 1)
        self.assertEqual(len(self.db.dreams), 1)

    async def test_checkpoint_resume_without_provider(self):
        self.persist.side_effect = RuntimeError('database disconnected')
        with self.assertRaises(HTTPException): await self.run_command()
        self.assertEqual(self.db.rows[('alice','command-1')]['state'], 'generated')
        async def restored(row): self.db.dreams[row['id']] = row
        self.persist.side_effect = restored
        self.assertEqual((await self.run_command())['id'], 'dream-1')
        self.assertEqual(self.generate.await_count, 1)

    async def test_concurrent_command_is_rejected_while_provider_runs(self):
        entered, release = asyncio.Event(), asyncio.Event()
        async def generate():
            entered.set()
            await release.wait()
            return {'id': 'dream-1','user_id':'alice'}, {'id':'dream-1'}
        self.generate.side_effect = generate
        first = asyncio.create_task(self.run_command())
        await entered.wait()
        with self.assertRaises(HTTPException) as result: await self.run_command()
        self.assertEqual(result.exception.detail['error'], 'command_running')
        release.set()
        await first
        self.assertEqual(self.generate.await_count, 1)

    async def test_payload_conflict_and_owner_isolation(self):
        await self.run_command()
        with self.assertRaises(HTTPException) as result: await self.run_command(payload={'text':'changed'})
        self.assertEqual(result.exception.status_code, 409)
        self.generate.return_value = ({'id':'dream-2','user_id':'bob'}, {'id':'dream-2'})
        self.assertEqual((await self.run_command('bob'))['id'], 'dream-2')
        self.assertEqual(len(self.db.rows), 2)

    async def test_unknown_interruption_cannot_start_a_second_generation(self):
        self.generate.side_effect = RuntimeError('provider response lost')
        with self.assertRaises(RuntimeError): await self.run_command()
        with self.assertRaises(HTTPException): await self.run_command()
        self.assertEqual(self.generate.await_count, 1)

    async def test_explicit_provider_unavailable_can_be_retried(self):
        self.generate.side_effect = HTTPException(503, detail={'error':'synthesis_failed'})
        with self.assertRaises(HTTPException): await self.run_command()
        self.generate.side_effect = None
        self.assertEqual((await self.run_command())['id'], 'dream-1')
        self.assertEqual(self.generate.await_count, 2)
