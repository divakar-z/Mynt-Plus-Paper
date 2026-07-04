#!/usr/bin/env python3
"""Prune unused shadcn_flutter Geist/GeistMono weights from a web build.

The shadcn_flutter package bundles the entire Geist + GeistMono families
(17 weights each: every italic, Thin, Light, ExtraLight, Black, UltraBlack,
UltraLight...). On the web, the CanvasKit renderer downloads EVERY font listed
in assets/FontManifest.json BEFORE it paints the first frame, so all 34 files
(~5MB) sit on the critical path even though the UI only ever uses the common
upright weights.

This script rewrites build/web/assets/FontManifest.json to keep only the
weights in KEEP_WEIGHTS (upright 400/500/600/700) for the GeistSans/GeistMono
families and deletes the now-unreferenced font files from disk.

Run it AFTER `flutter build web --release`:

    python3 tool/prune_web_fonts.py build/web

It is idempotent and safe to run repeatedly. Only shadcn Geist families are
touched; icon fonts (Lucide/Bootstrap/Radix), Material, Inter and the app's own
Geist family are left untouched.
"""
import json
import os
import sys

# Upright weights to keep for the variable-ish Geist families.
KEEP_WEIGHTS = {400, 500, 600, 700}
# Weight/italic-prune these shadcn families (matched by substring on the family name).
TARGET_FAMILIES = ("GeistSans", "GeistMono")

# Families to DROP ENTIRELY from the WEB manifest — verified unused on web by a
# 4-agent audit (2026-06-23). CanvasKit downloads every manifest font before the
# first frame, so these were pure cost on the post-login critical path. Matched by
# substring. WEB-ONLY: pubspec is shared with the mobile build, so we strip them
# from the built web manifest here, never from pubspec.yaml / dependencies.
#   - InterVariable                 : web uses 'Geist'/'tenon'; Inter is a non-web fallback only
#   - GeistMono                     : no web widget consumes theme.typography.mono / .mono
#   - syncfusion_flutter_datagrid/* : datagrid package declared but never imported anywhere
DROP_FAMILIES = ("InterVariable", "GeistMono", "syncfusion_flutter_datagrid")


def should_keep(font: dict) -> bool:
    # Drop every italic; drop any weight outside the keep set.
    if str(font.get("style", "")).lower() == "italic":
        return False
    weight = font.get("weight")
    if weight is None:
        return True  # no weight metadata -> keep (can't classify)
    return int(weight) in KEEP_WEIGHTS


def main() -> int:
    web_dir = sys.argv[1] if len(sys.argv) > 1 else "build/web"
    manifest_path = os.path.join(web_dir, "assets", "FontManifest.json")
    if not os.path.isfile(manifest_path):
        print(f"[prune-fonts] FontManifest not found: {manifest_path}", file=sys.stderr)
        return 1

    with open(manifest_path) as f:
        families = json.load(f)

    removed_assets = []
    kept = dropped = 0
    new_families = []
    for fam in families:
        name = fam.get("family", "")
        # Drop entire families that are verified unused on web.
        if any(d in name for d in DROP_FAMILIES):
            for font in fam.get("fonts", []):
                if font.get("asset"):
                    removed_assets.append(font["asset"])
                dropped += 1
            continue  # omit this family from the manifest
        # Families we don't touch: keep as-is.
        if not any(t in name for t in TARGET_FAMILIES):
            kept += len(fam.get("fonts", []))
            new_families.append(fam)
            continue
        # Weight/italic-prune the shadcn variable families.
        keep_list, drop_list = [], []
        for font in fam.get("fonts", []):
            (keep_list if should_keep(font) else drop_list).append(font)
        fam["fonts"] = keep_list
        kept += len(keep_list)
        dropped += len(drop_list)
        for font in drop_list:
            asset = font.get("asset")
            if asset:
                removed_assets.append(asset)
        new_families.append(fam)
    families = new_families

    # Delete the unreferenced files from the asset bundle.
    deleted_bytes = 0
    for asset in removed_assets:
        path = os.path.join(web_dir, "assets", asset)
        if os.path.isfile(path):
            deleted_bytes += os.path.getsize(path)
            os.remove(path)

    with open(manifest_path, "w") as f:
        json.dump(families, f)

    print(
        f"[prune-fonts] kept {kept} fonts, dropped {dropped} "
        f"(freed {deleted_bytes/1024:.0f} KB across {len(removed_assets)} files)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
