#!/usr/bin/env python3
from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[1]
venv=root/'build/formal-venv'
z3=venv/'bin/z3'
if not z3.exists():
    subprocess.run([sys.executable,'-m','venv',str(venv)],check=True)
    subprocess.run([str(venv/'bin/pip'),'install','--disable-pip-version-check','z3-solver==4.16.0.0'],check=True)
print(f'FORMAL_ENV|z3={z3.relative_to(root)}|status=PASS')
