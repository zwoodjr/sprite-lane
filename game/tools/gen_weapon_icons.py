"""Retired: the base weapon icons (icons/weapons/weapon_<hero>.png) and every
Common-Epic IconSet weapon icon are painted by gen_legendary_icons.py now.
usage: python3 tools/gen_weapon_icons.py   (from game/; just runs that)"""
import os
import runpy

runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen_legendary_icons.py"), run_name="__main__")
