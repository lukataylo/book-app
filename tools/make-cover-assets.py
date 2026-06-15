#!/usr/bin/env python3
"""Wrap authored 2:3 SVG covers into Covers.xcassets imagesets.

Usage: python3 tools/make-cover-assets.py <svg_dir>
Each <slug>.svg in <svg_dir> becomes
  BookApp/Resources/Covers.xcassets/cover-<slug>.imageset/{cover-<slug>.svg, Contents.json}
with preserves-vector-representation so it renders crisp at any size.
"""
import json, os, sys, glob, shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "BookApp/Resources/Covers.xcassets")

def main(svg_dir):
    svgs = sorted(glob.glob(os.path.join(svg_dir, "*.svg")))
    if not svgs:
        print("no SVGs found in", svg_dir); sys.exit(1)
    made = 0
    for svg in svgs:
        slug = os.path.splitext(os.path.basename(svg))[0]
        name = f"cover-{slug}"
        iset = os.path.join(ASSETS, f"{name}.imageset")
        os.makedirs(iset, exist_ok=True)
        shutil.copyfile(svg, os.path.join(iset, f"{name}.svg"))
        contents = {
            "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
            "properties": {"preserves-vector-representation": True},
        }
        with open(os.path.join(iset, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)
        made += 1
    print(f"wrote {made} imageset(s) into {ASSETS}")

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/cover-svgs")
