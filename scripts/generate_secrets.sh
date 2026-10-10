#!/usr/bin/env bash
# Genera FrameArt/Secrets.generated.swift (en .gitignore; NUNCA versionar).
#
# Fuentes, por prioridad:
#   1. Variables de entorno (CI): REVENUECAT_API_KEY, FRAME_STUDIO_API_ORIGIN
#   2. Config/Secrets.env (local, en .gitignore). Copia Config/Secrets.example.env.
# Si no hay ninguna fuente, se conservan los valores locales no relacionados con publicación.
# Si no existe, se crea con valores vacíos para que el proyecto compile (publicar fallará con un error claro).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/Config/Secrets.env"
OUT="$ROOT/FrameArt/Secrets.generated.swift"

if [[ -r "$ENV_FILE" ]] && cat "$ENV_FILE" >/dev/null 2>&1; then
  set -a; # shellcheck disable=SC1090
  source "$ENV_FILE"; set +a
fi

have_source=0
for v in REVENUECAT_API_KEY FRAME_STUDIO_API_ORIGIN; do
  [[ -n "${!v:-}" ]] && have_source=1
done

if [[ $have_source -eq 0 && -f "$OUT" ]]; then
  # Preserve existing local non-publish settings while removing the legacy
  # credential from future client builds. This does not revoke old binaries.
  TMP="$(mktemp)"
  awk '
    /^[[:space:]]*\/\/\/ Clave compartida LEGACY\./ { next }
    /^[[:space:]]*static let publishKey =/ { next }
    { print }
  ' "$OUT" > "$TMP"
  if cmp -s "$TMP" "$OUT"; then rm -f "$TMP"; else mv "$TMP" "$OUT"; fi
  echo "generate_secrets: sin fuentes; se conservan valores locales y se retira la clave legacy del cliente"
  exit 0
fi

esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
TMP="$(mktemp)"
cat > "$TMP" <<SWIFT
// Generado por scripts/generate_secrets.sh. NO EDITAR NI VERSIONAR.
enum FrameStudioSecrets {
    static let revenueCatAPIKey = "$(esc "${REVENUECAT_API_KEY:-}")"
    static let apiOrigin = "$(esc "${FRAME_STUDIO_API_ORIGIN:-https://frame-studio.netlify.app}")"
}
SWIFT
if cmp -s "$TMP" "$OUT" 2>/dev/null; then rm -f "$TMP"; else mv "$TMP" "$OUT"; fi
echo "generate_secrets: escrito $OUT"
