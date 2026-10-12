# Frame Studio

Nombre en pantalla: **Frame Studio**. Bundle ID: `app.framestudio.ios` (tests: `app.framestudio.ios.tests`).

> Cambio de bundle ID (antes `com.alancruzr.frameart`): es una app nueva para iOS. Requiere un App ID nuevo con App Attest y Associated Domains, un registro nuevo en App Store Connect y `APPLE_BUNDLE_ID=app.framestudio.ios` en Netlify. Las instalaciones nuevas crean su propio contenedor; el store de SwiftData (`default.store` en Application Support) no depende del bundle ID, pero los datos de la app anterior no se migran.

App nativa de iOS (SwiftUI, Swift 6, SwiftData) para artistas. Añades la foto de una pintura —cámara, fototeca o Archivos— o un escaneo 3D (`.usdz` / `.reality`), la ves en tu pared con ARKit/RealityKit y la compartes para que un cliente la abra **sin instalar la app**.

**Un solo enlace público funciona en iPhone y Android.** No envíes solo el `.usdz`: ese archivo es de Apple. El visor en `docs/index.html` (GitHub Pages) elige el formato:

| Cliente | Qué abre | Formato |
| --- | --- | --- |
| Safari en iPhone / iPad | AR Quick Look (`rel="ar"`, `ios-src`) | `.usdz` |
| Chrome en Android | Google Scene Viewer o WebXR (`ar-modes="webxr scene-viewer quick-look"`) | `.glb` |
| Escritorio | Vista 3D de `<model-viewer>` | `.glb` |

La app del artista sigue siendo solo iOS. Exporta **USDZ y GLB** de cada pintura (foto). El cliente no usa ARKit.

Requisito: **iOS 18.0 o posterior** (deployment target 18.0; se compila con el SDK de iOS 26+). Liquid Glass se usa solo en iOS 26+ (`#available`); en iOS 18–25 los botones usan estilos `bordered`. La vista previa AR en la app necesita un **iPhone o iPad real**.

Visor público: https://frame-studio.netlify.app/{estudio}/{obra}/ (Netlify es el hosting principal; el visor de GitHub Pages en `docs/` está en retirada, ver `docs/DEPRECATED.md`).

Legales: https://frame-studio.netlify.app/privacy/ · /terms/ · /support/

Query: `?title=Atardecer&glb=model.glb&usdz=model.usdz`

## Onboarding

Cuatro pasos breves (se puede **Saltar**): bienvenida, qué vas a compartir, qué se pierde con una foto, cámara y fotos. Ritmo de una pregunta por pantalla. Sin paywall. Tras completar, pestañas Obras y Nueva.

## ARKit, Quick Look y Scene Viewer

- **En la app (artista, iOS):** RealityKit `ARView` + detección de planos verticales (`ARWorldTrackingConfiguration.planeDetection = .vertical`) y `AnchorEntity(.plane(.vertical, classification: .wall, …))`. Eso es ARKit, solo para el artista.
- **En el cliente iPhone:** Apple AR Quick Look abre el `.usdz` desde Mensajes, WhatsApp, Archivos o Safari. No instala Frame Studio.
- **En el cliente Android:** `<model-viewer>` lanza WebXR o Scene Viewer con el `.glb` (`ar-placement="wall"` → `enable_vertical_placement=true`). Tampoco instala Frame Studio.
- **No hay pila web-AR inventada** más allá de APIs de Apple (Quick Look) y el patrón oficial de Google (`model-viewer` / Scene Viewer): `src` = GLB, `ios-src` = USDZ, `ar-modes="webxr scene-viewer quick-look"`.

`Entity.write(to:)` de RealityKit (iOS 18+) escribe archivos `.reality`, no USDZ. Frame Studio genera el USDZ con USDA + ZIP alineado a 64 bytes (especificación Pixar) y el GLB como glTF 2.0 binario con `KHR_materials_unlit`.

## Abrir en Xcode

1. Abre `FrameArt.xcodeproj`.
2. Elige un equipo de firma en el target **FrameArt**.
3. Bundle ID: `app.framestudio.ios`.
4. Ejecuta en un iPhone o iPad real para AR. El simulador sirve para onboarding, lista, alta y exportación.

Permisos (Info.plist generado): cámara y fototeca. El onboarding los pide; se pueden conceder después en Ajustes.

## Configuración local (secretos)

`FrameArt/Secrets.generated.swift` está en `.gitignore` y lo genera la fase de build **Generate Secrets** (`scripts/generate_secrets.sh`).

1. `cp Config/Secrets.example.env Config/Secrets.env` y rellena los valores de cliente que correspondan (archivo ignorado por git).
2. Xcode ejecuta `./scripts/generate_secrets.sh` en cada build. El generador no escribe `FRAME_STUDIO_PUBLISH_KEY` en la app; conserva los valores locales no relacionados con publicación si no hay entradas nuevas.
3. En CI, define `REVENUECAT_API_KEY` si se necesita; la clave de publicación no es una variable de build iOS.

Los builds nuevos publican con App Attest y no contienen la clave legacy. Los binarios antiguos pueden seguir usándola mientras `FRAME_STUDIO_LEGACY_KEY_ENABLED` permanezca activo en Netlify. Mantén esa compatibilidad hasta verificar la migración de los clientes; quitar la clave de una fuente o de builds nuevos no revoca credenciales ya empaquetadas en binarios antiguos.

## Publicación segura (App Attest)

- La app obtiene un token de 15 min con App Attest (`FrameArt/Services/DeviceAuth.swift`) vía `/api/auth/challenge`, `/api/auth/attest` y `/api/auth/assert`. El primer dispositivo que usa un slug de estudio queda como dueño.
- `/api/publish` y `/api/unpublish` exigen token (o la clave legacy mientras `FRAME_STUDIO_LEGACY_KEY_ENABLED` ≠ `false`), validan el tipo real de archivo y aplican límites: poster 3 MB, USDZ/GLB 6 MB, meta 4 KB, 200 obras por estudio, 60 subidas/h por dispositivo, 120/h por IP.
- Variables en Netlify: `FRAME_STUDIO_SESSION_SECRET` (mínimo 32 caracteres), `APPLE_TEAM_ID`; `APPLE_BUNDLE_ID` y `APP_ATTEST_ENV` tienen valores por defecto, pero pueden fijarse explícitamente por entorno. `APP_ATTEST_ALLOW_DEVELOPMENT` queda desactivado por defecto. No lo actives en producción sin una aprobación y una ventana de prueba concretas; es preferible validar builds de desarrollo en un entorno Deploy Preview aislado.
- Release gate: configura el backend y habilita App Attest para el App ID antes de distribuir un build nuevo; los clientes nuevos fallan de forma cerrada si App Attest no está disponible. Mantén el fallback legacy del servidor hasta verificar la migración de los binarios antiguos.
- Tests del servidor: `npm ci && npm run typecheck && npm test`.

## Cómo abre el cliente la obra

**Opción A — un enlace (iPhone y Android)**  
GitHub Pages sirve `docs/`. El cliente abre https://alancruzr.github.io/frame-art/ :

- iPhone: botón *Ver en mi espacio* → Quick Look con `model.usdz`.
- Android: el mismo botón → WebXR o Scene Viewer con `model.glb`.

Coloca junto a `docs/index.html` los archivos `model.usdz` y `model.glb` que exporta la app (Detalle → compartir). Query opcional:

```
https://alancruzr.github.io/frame-art/?title=Atardecer&glb=model.glb&usdz=model.usdz&placement=wall
```

**Opción B — archivo en el chat (sin página)**  
- iPhone: comparte el USDZ; Mensajes / WhatsApp / Archivos abren Quick Look.
- Android: comparte el GLB; se abre con Scene Viewer u otra app glTF.

La opción A unifica iPhone y Android en **un** enlace. Un enlace único por obra (con el archivo ya hosteado) necesita subir el USDZ/GLB; Pages es estático.

## Licencia

MIT. Copyright Alan Cruz.

## Suscripciones (RevenueCat) y analítica (Firebase)

- **RevenueCat**: pon `REVENUECAT_API_KEY` (clave pública iOS, `appl_…`) en `Config/Secrets.env` o como variable de entorno en CI. Sin clave la app funciona: el paywall muestra "no configurado" en DEBUG y publicar queda limitado a `ProPlan.defaultFreePublishedLimit` (3) obras. Entitlement `pro`, offering `default`, productos `app.framestudio.ios.pro.monthly`, `.annual`, `.lifetime`. Para probar sin App Store Connect, el esquema usa `FrameArt/FrameStudio.storekit`. El límite gratis se cambia sin recompilar con el argumento de arranque `-FreePublishedLimit N`.
- **Firebase**: descarga `GoogleService-Info.plist` (app iOS `app.framestudio.ios`) a `Config/GoogleService-Info.plist` (en .gitignore). Una fase de build lo copia al bundle; sin él, Firebase no se configura. Se usa `FirebaseAnalyticsCore` (sin IDFA/AdSupport, sin ATT) y Crashlytics (apagado en DEBUG/simulador; fuerza con `-FrameStudioCrashReportingEnabled YES`). Los dSYMs se suben solo en Archive y solo si el plist existe (`scripts/upload_crashlytics_dsyms.sh`).
- Eventos (`FrameArt/Services/Analytics.swift`): `onboarding_step`, `onboarding_*`, `paywall_viewed/plan_selected/purchase_*/restore/dismissed`, `artwork_added`, `artwork_published`, `artwork_shared`, `publish_limit_reached`, `ar_opened`. Nunca se envían títulos, nombres, slugs ni URLs.

## Avisos "tu cliente abrió la obra" (APNs)

- App: tras el **primer** envío correcto se ofrece activar avisos; con permiso, el token APNs se manda a `POST /api/devices/push-token` con la sesión App Attest del estudio. Tocar el aviso abre la obra vía `DeepLinkRouter`. El detalle de la obra muestra "Vista X veces" (`GET /api/views`, solo el dueño).
- Visor: beacon `POST /api/views`. Ignora bots y previsualizadores, y el navegador del artista si abrió el enlace con `?owner=1` una vez. Un visitante cuenta una vez cada 30 min; como mucho un aviso por obra cada 30 min. No se guarda la IP ni datos del cliente.
- Netlify env: `APNS_KEY_ID`, `APNS_TEAM_ID` (ML4VB5PQ6H), `APNS_PRIVATE_KEY` (contenido del .p8; se aceptan `\n` escapados), `APNS_ENV` (`sandbox` para builds de Xcode, `production` para TestFlight/App Store), `APPLE_BUNDLE_ID` (topic). Sin estas variables no se envía nada.
