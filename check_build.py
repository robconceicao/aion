import subprocess
import os

def run_build():
    frontend_dir = os.path.join(os.path.dirname(__file__), 'frontend')
    print("Running flutter build web in", frontend_dir)
    result = subprocess.run(['flutter', 'build', 'web'], cwd=frontend_dir, capture_output=True, text=True)
    with open(os.path.join(frontend_dir, 'build_output.txt'), 'w', encoding='utf-8') as f:
        f.write(result.stdout)
        f.write("\n\n--- STDERR ---\n\n")
        f.write(result.stderr)
    print("Build output saved to build_output.txt")

if __name__ == '__main__':
    run_build()
