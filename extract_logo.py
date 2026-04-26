import re
import base64
import os

def extract_logo():
    print("Extraindo logo base64 do JSX...")
    frontend_dir = os.path.join(os.path.dirname(__file__), 'frontend')
    assets_dir = os.path.join(frontend_dir, 'assets', 'images')
    os.makedirs(assets_dir, exist_ok=True)
    
    jsx_path = r'C:\Users\robtc\Downloads\diario-de-sonhos-v3-logo.jsx'
    
    with open(jsx_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    match = re.search(r'LOGO_SRC = "data:image/[^;]+;base64,([^\"]+)"', content)
    if match:
        b64 = match.group(1)
        out_path = os.path.join(assets_dir, 'logo.jpg')
        with open(out_path, 'wb') as out:
            out.write(base64.b64decode(b64))
        print(f"Logo salvo com sucesso em: {out_path}")
    else:
        print("Erro: Não foi possível encontrar LOGO_SRC no arquivo JSX.")

if __name__ == '__main__':
    extract_logo()
