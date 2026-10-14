#!/bin/sh
# Copia Config/GoogleService-Info.plist al bundle si existe. Sin él, Firebase queda desactivado.
set -eu
SRC="$SRCROOT/Config/GoogleService-Info.plist"
DST="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/GoogleService-Info.plist"
if [ -f "$SRC" ]; then
  cp "$SRC" "$DST"
  echo "GoogleService-Info.plist copiado"
else
  rm -f "$DST"
  echo "note: Config/GoogleService-Info.plist no existe; Firebase desactivado en este build"
fi
