#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEMP_ROOT"' EXIT
mkdir -p "$TEMP_ROOT/scripts" "$TEMP_ROOT/Config" "$TEMP_ROOT/FrameArt"
cp "$REPO_ROOT/scripts/generate_secrets.sh" "$TEMP_ROOT/scripts/generate_secrets.sh"
chmod +x "$TEMP_ROOT/scripts/generate_secrets.sh"

assert_absent() {
  if grep -Fq "$1" "$2"; then
    echo "generate_secrets test failed: forbidden client setting present" >&2
    exit 1
  fi
}

# An existing generated file may contain an old local key. Keep its unrelated
# local values, but remove that field before a future client build.
cat > "$TEMP_ROOT/FrameArt/Secrets.generated.swift" <<'SWIFT'
enum FrameStudioSecrets {
    /// Clave compartida LEGACY. Solo se usa en clientes antiguos.
    static let publishKey = "SYNTHETIC_OLD_KEY_MARKER"
    static let revenueCatAPIKey = "SYNTHETIC_REVENUECAT_MARKER"
    static let apiOrigin = "https://frame-studio.test"
}
SWIFT
env -u FRAME_STUDIO_PUBLISH_KEY -u REVENUECAT_API_KEY -u FRAME_STUDIO_API_ORIGIN \
  "$TEMP_ROOT/scripts/generate_secrets.sh" >/dev/null
assert_absent 'static let publishKey' "$TEMP_ROOT/FrameArt/Secrets.generated.swift"
assert_absent 'SYNTHETIC_OLD_KEY_MARKER' "$TEMP_ROOT/FrameArt/Secrets.generated.swift"
grep -Fq 'SYNTHETIC_REVENUECAT_MARKER' "$TEMP_ROOT/FrameArt/Secrets.generated.swift"

# A publish-key-only environment must never create a client credential.
rm -f "$TEMP_ROOT/FrameArt/Secrets.generated.swift"
env -u REVENUECAT_API_KEY -u FRAME_STUDIO_API_ORIGIN \
  FRAME_STUDIO_PUBLISH_KEY=SYNTHETIC_ENV_KEY_MARKER \
  "$TEMP_ROOT/scripts/generate_secrets.sh" >/dev/null
assert_absent 'static let publishKey' "$TEMP_ROOT/FrameArt/Secrets.generated.swift"
assert_absent 'SYNTHETIC_ENV_KEY_MARKER' "$TEMP_ROOT/FrameArt/Secrets.generated.swift"

# A local config can still supply non-publish client settings without embedding its legacy key.
cat > "$TEMP_ROOT/Config/Secrets.env" <<'ENV'
FRAME_STUDIO_PUBLISH_KEY=SYNTHETIC_CONFIG_KEY_MARKER
REVENUECAT_API_KEY=SYNTHETIC_CONFIG_REVENUECAT_MARKER
ENV
env -u FRAME_STUDIO_PUBLISH_KEY -u REVENUECAT_API_KEY -u FRAME_STUDIO_API_ORIGIN \
  "$TEMP_ROOT/scripts/generate_secrets.sh" >/dev/null
assert_absent 'static let publishKey' "$TEMP_ROOT/FrameArt/Secrets.generated.swift"
assert_absent 'SYNTHETIC_CONFIG_KEY_MARKER' "$TEMP_ROOT/FrameArt/Secrets.generated.swift"
grep -Fq 'SYNTHETIC_CONFIG_REVENUECAT_MARKER' "$TEMP_ROOT/FrameArt/Secrets.generated.swift"

echo "generate_secrets migration tests passed"
