"""Bentley, scout: rig for tools/pet_puppet.py (satchel + glowing vial kept)."""
RIG = {
    "panel": (288, 64, 548, 344),
    "target": {"h": 122, "cx": 125, "feet": 235},
    "body_p": (125, 150),
    "sit_p": (86, 182),
    "legs": {
        "FL": {"x": (44, 91), "cut": 182, "hip": (68, 182), "knee": (66, 215), "paw": (62, 242), "near": True},
        "FR": {"x": (91, 132), "cut": 188, "hip": (108, 188), "knee": (106, 222), "paw": (105, 252), "near": True},
        "BF": {"x": (136, 180), "cut": 172, "hip": (155, 172), "knee": (152, 200), "paw": (152, 222), "near": False},
        "BN": {"x": (186, 230), "cut": 175, "hip": (205, 175), "knee": (203, 208), "paw": (210, 232), "near": True},
    },
    "order": {"behind": ["BF"], "front": ["BN", "FR", "FL"]},
    "tail": {"poly": [(205, 126), (252, 122), (252, 182), (205, 182)], "base_x": 205, "pivot": (212, 150)},
    "head": {
        "poly": [(28, 14), (144, 14), (144, 94), (120, 100), (100, 104), (72, 106), (58, 100), (28, 100)],
        "pivot": (86, 100), "face": ((86, 62), (32, 46)),
        "neck": ((86, 106), (40, 20)), "neck_clone_dy": 76, "neck_src_x": (50, 100),
    },
    "ears": {
        "earL": {"poly": [(26, 34), (58, 26), (64, 60), (58, 100), (40, 102), (26, 90)], "pivot": (54, 42), "dir": 1},
        "earR": {"poly": [(110, 30), (144, 36), (144, 92), (130, 102), (114, 98), (112, 60)], "pivot": (118, 42), "dir": -1},
    },
    "extras": [
        {"name": "ring", "poly": [(78, 120), (98, 120), (98, 142), (78, 142)], "pivot": (88, 121), "clone_dy": 36},
        # satchel with the vial hangs in front of the near legs, swings a little
        {"name": "satchel", "poly": [(106, 136), (160, 136), (160, 188), (106, 188)], "pivot": (132, 138),
         "front": True, "swing": 0.35},
    ],
}
