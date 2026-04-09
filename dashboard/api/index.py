"""
Vercel serverless entry for the FastAPI analytics app.
Local dev: run `python server.py` from the dashboard folder (no Mangum).
"""
import sys
from pathlib import Path

_root = Path(__file__).resolve().parent.parent
if str(_root) not in sys.path:
    sys.path.insert(0, str(_root))

from mangum import Mangum
from server import app

handler = Mangum(app, lifespan="off")
