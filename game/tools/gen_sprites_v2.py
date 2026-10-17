#!/usr/bin/env python3
"""Compatibility wrapper — full Dust Apothecary pixel set lives in gen_sprites.py."""
import runpy
from pathlib import Path

if __name__ == "__main__":
    runpy.run_path(str(Path(__file__).with_name("gen_sprites.py")), run_name="__main__")
