# Frame Art

App nativa de iOS (SwiftUI, Swift 6, SwiftData) para artistas. Añades la foto de una pintura —cámara, fototeca o Archivos— o un escaneo 3D (`.usdz` / `.reality`), la ves en tu pared con ARKit/RealityKit y la compartes para que un cliente la abra **sin instalar la app**.

**Un solo enlace público funciona en iPhone y Android.** No envíes solo el `.usdz`: ese archivo es de Apple. El visor en `web/index.html` elige el formato:

| Cliente | Qué abre | Formato |
| --- | --- | --- |
| Safari en iPhone / iPad | AR Quick Look (`rel="ar"`, `ios-src`) | `.usdz` |
| Chrome en Android | Google Scene Viewer o WebXR (`ar-modes="webxr scene-viewer quick-look"`) | `.glb` |
| Escritorio | Vista 3D de `<model-viewer>` | `.glb` |

La app del artista sigue siendo solo iOS. Exporta **USDZ y GLB** de cada pintura (foto). El cliente no usa ARKit.

Requisito: **iOS 18 o posterior** (el proyecto apunta a iOS 26). La vista previa AR en la app necesita un **iPhone o iPad real**.

## ARKit, Quick Look y Scene Viewer

- **En la app (artista, iOS):** RealityKit `ARView` + detección de planos verticales. Eso es ARKit, solo para el artista.
- **En el cliente iPhone:** Apple AR Quick Look abre el `.usdz` desde Mensajes, WhatsApp, Archivos o Safari.
- **En el cliente Android:** `<model-viewer>` lanza WebXR o Scene Viewer con el `.glb`.

## Abrir en Xcode

1. Abre `FrameArt.xcodeproj`.
2. Elige un equipo de firma en el target **FrameArt**.
3. Bundle ID: `com.alancruzr.frameart`.
4. Ejecuta en un dispositivo real para AR.

## Cómo abre el cliente la obra

Publica `web/` por HTTPS (GitHub Pages). Un enlace abre Quick Look en iPhone y Scene Viewer en Android.

## Licencia

MIT. Copyright Alan Cruz.
