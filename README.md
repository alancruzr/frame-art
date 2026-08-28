# Frame Studio

Nombre en pantalla: **Frame Studio**. Bundle: `com.alancruzr.frameart` (no cambiar).

App nativa de iOS (SwiftUI, Swift 6, SwiftData) para artistas. Añades la foto de una pintura —cámara, fototeca o Archivos— o un escaneo 3D (`.usdz` / `.reality`), la ves en tu pared con ARKit/RealityKit y la compartes para que un cliente la abra **sin instalar la app**.

**Un solo enlace público funciona en iPhone y Android.** No envíes solo el `.usdz`: ese archivo es de Apple. El visor en `docs/index.html` (GitHub Pages) elige el formato:

| Cliente | Qué abre | Formato |
| --- | --- | --- |
| Safari en iPhone / iPad | AR Quick Look (`rel="ar"`, `ios-src`) | `.usdz` |
| Chrome en Android | Google Scene Viewer o WebXR (`ar-modes="webxr scene-viewer quick-look"`) | `.glb` |
| Escritorio | Vista 3D de `<model-viewer>` | `.glb` |

La app del artista sigue siendo solo iOS. Exporta **USDZ y GLB** de cada pintura (foto). El cliente no usa ARKit.

Requisito: **iOS 18 o posterior** (el proyecto apunta a iOS 26). La vista previa AR en la app necesita un **iPhone o iPad real**.

Visor público: https://alancruzr.github.io/frame-art/

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
3. Bundle ID: `com.alancruzr.frameart`.
4. Ejecuta en un iPhone o iPad real para AR. El simulador sirve para onboarding, lista, alta y exportación.

Permisos (Info.plist generado): cámara y fototeca. El onboarding los pide; se pueden conceder después en Ajustes.

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
