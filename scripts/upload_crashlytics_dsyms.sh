#!/bin/sh
# Sube dSYMs a Crashlytics (solo Archive y solo si hay GoogleService-Info.plist).
set -eu
if [ "${ACTION:-}" != "install" ]; then exit 0; fi
PLIST="$SRCROOT/Config/GoogleService-Info.plist"
if [ ! -f "$PLIST" ]; then
  echo "warning: sin Config/GoogleService-Info.plist; no se suben dSYMs a Crashlytics"
  exit 0
fi
RUN=""
for c in \
  "${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run" \
  "${BUILD_DIR%/Build/*}/SourcePackages/artifacts/firebase-ios-sdk/FirebaseCrashlytics/run"
do
  if [ -x "$c" ]; then RUN="$c"; break; fi
done
if [ -z "$RUN" ]; then
  echo "warning: no se encontró el script run de Crashlytics; dSYMs sin subir"
  exit 0
fi
"$RUN" -gsp "$PLIST"
