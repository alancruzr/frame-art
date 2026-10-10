#!/usr/bin/env bash
# Genera FrameArt/Secrets.generated.swift (en .gitignore; NUNCA versionar).
#
# Fuentes, por prioridad:
#   1. Variables de entorno (CI): FRAME_STUDIO_PUBLISH_KEY, REVENUECAT_API_KEY, FRAME_STUDIO_API_ORIGIN
#   2. Config/Secrets.env (local, en .gitignore). Copia Config/Secrets.example.env.
# Si no hay ninguna fuente y el archivo generado ya existe, NO se toca (conserva tu configuración local).
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
for v in FRAME_STUDIO_PUBLISH_KEY REVENUECAT_API_KEY FRAME_STUDIO_API_ORIGIN; do
  [[ -n "${!v:-}" ]] && have_source=1
done

if [[ $have_source -eq 0 && -f "$OUT" ]]; then
  echo "generate_secrets: sin fuentes; se conserva $OUT"
  exit 0
fi

esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
TMP="$(mktemp)"
cat > "$TMP" <<SWIFT
// Generado por scripts/generate_secrets.sh. NO EDITAR NI VERSIONAR.
enum FrameStudioSecrets {
    /// Clave compartida LEGACY. Solo se usa si el servidor tiene activado FRAME_STUDIO_LEGACY_KEY_ENABLED.
    static let publishKey = "$(esc "${FRAME_STUDIO_PUBLISH_KEY:-}")"
    static let revenueCatAPIKey = "$(esc "${REVENUECAT_API_KEY:-}")"
    static let apiOrigin = "$(esc "${FRAME_STUDIO_API_ORIGIN:-https://frame-studio.netlify.app}")"
}
SWIFT
if cmp -s "$TMP" "$OUT" 2>/dev/null; then rm -f "$TMP"; else mv "$TMP" "$OUT"; fi
echo "generate_secrets: escrito $OUT"
