"""Offline regressions executing the real persistence function, without provider imports."""
import ast
import asyncio
import unittest
from pathlib import Path
from types import SimpleNamespace
source = Path(__file__).parents[1] / "app/routers/dreams.py"
tree = ast.parse(source.read_text(encoding="utf-8"))
function = next(n for n in tree.body if isinstance(n, ast.AsyncFunctionDef) and n.name == "_persist_dream_dual_with_retry")
class Database:
    def __init__(self, lost_read=False, lost_insert=False, foreign=False):
        self.row = {"id":"operation","user_id":"B"} if foreign else None
        self.lost_read=lost_read; self.lost_insert=lost_insert; self.inserts=0
    def table(self, _): return Query(self)
class Query:
    def __init__(self, db): self.db=db; self.filters={}; self.data=None
    def select(self, _): return self
    def eq(self,k,v): self.filters[k]=v; return self
    def limit(self,_): return self
    def insert(self,data): self.data=data; return self
    def execute(self):
        db=self.db
        if self.data:
            db.inserts+=1
            if db.row: raise RuntimeError("duplicate")
            db.row=dict(self.data)
            if db.lost_insert: raise RuntimeError("lost response")
            return SimpleNamespace(data=[db.row])
        if db.row and db.lost_read and db.inserts:
            db.lost_read=False; raise RuntimeError("temporary read timeout")
        return SimpleNamespace(data=[db.row] if db.row and all(db.row.get(k)==v for k,v in self.filters.items()) else [])
async def no_sleep(_): pass
def actual(db):
    scope={"get_supabase_service":lambda:db,"asyncio":SimpleNamespace(sleep=no_sleep)}
    exec(compile(ast.Module(body=[function],type_ignores=[]),str(source),"exec"),scope)
    return scope[function.name]
class PersistenceTests(unittest.IsolatedAsyncioTestCase):
    async def test_committed_insert_followed_by_read_timeout(self):
        db=Database(lost_read=True)
        await actual(db)({"id":"operation","user_id":"A"})
        self.assertEqual(db.inserts,1)
    async def test_lost_insert_response_is_recovered_on_final_attempt(self):
        db=Database(lost_insert=True)
        await actual(db)({"id":"operation","user_id":"A"},max_attempts=1)
        self.assertEqual(db.row["user_id"],"A")
    async def test_foreign_owned_id_never_confirms_or_overwrites(self):
        db=Database(foreign=True)
        with self.assertRaises(RuntimeError):
            await actual(db)({"id":"operation","user_id":"A"})
        self.assertEqual(db.row["user_id"],"B")
    async def test_same_owner_different_payload_does_not_confirm_or_overwrite(self):
        db=Database(); db.row={"id":"operation","user_id":"A","relato":"original"}
        with self.assertRaisesRegex(RuntimeError,"divergente"):
            await actual(db)({"id":"operation","user_id":"A","relato":"changed"})
        self.assertEqual(db.row["relato"],"original")
        self.assertEqual(db.inserts,0)
if __name__ == "__main__": unittest.main()
