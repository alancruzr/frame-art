#!/usr/bin/env bash
# Regenera iconos derivados desde el master 1024x1024 (sin alfa). Requiere macOS (sips).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/FrameArt/Assets.xcassets/AppIcon.appiconset/AppIcon.png}"
ONB="$ROOT/FrameArt/Assets.xcassets/OnboardingAppIcon.imageset"
TMP="$(mktemp -d)"
sips -s format jpeg -s formatOptions 88 -Z 316 "$SRC" --out "$ONB/OnboardingIcon@2x.jpg" >/dev/null
sips -s format jpeg -s formatOptions 88 -Z 474 "$SRC" --out "$ONB/OnboardingIcon@3x.jpg" >/dev/null
for site in web LegalSite; do
  sips -Z 32 "$SRC" --out "$ROOT/$site/assets/favicon-32.png" >/dev/null
  sips -Z 180 "$SRC" --out "$ROOT/$site/assets/apple-touch-icon.png" >/dev/null
done
rm -rf "$TMP"
echo "Iconos regenerados. (icon-512.webp: regenerar con cwebp si cambia el master)"
