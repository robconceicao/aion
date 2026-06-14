content = open('app/routers/feedback.py').read()

terms = {
    'find_one':            'find_one',
    'insert_one':          'insert_one',
    'get_database':        'get_database',
    'current_user["_id"]': 'current_user["_id"]',
    'analytics_events':    'analytics_events',
}

failures = [name for name, literal in terms.items() if literal in content]

if failures:
    print('FAIL - residuos MongoDB encontrados:', failures)
else:
    print('OK - nenhum residuo MongoDB encontrado (5 termos verificados)')
    for name in terms:
        print(f'  {name}: ausente')
