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

- **En la app (artista, iOS):** RealityKit `ARView` + detección de planos verticales (`ARWorldTrackingConfiguration.planeDetection = .vertical`) y `AnchorEntity(.plane(.vertical, classification: .wall, …))`. Eso es ARKit, solo para el artista.
- **En el cliente iPhone:** Apple AR Quick Look abre el `.usdz` desde Mensajes, WhatsApp, Archivos o Safari. No instala Frame Art.
- **En el cliente Android:** `<model-viewer>` lanza WebXR o Scene Viewer con el `.glb` (`ar-placement="wall"` → `enable_vertical_placement=true`). Tampoco instala Frame Art.
- **No hay pila web-AR inventada** más allá de APIs de Apple (Quick Look) y el patrón oficial de Google (`model-viewer` / Scene Viewer), el mismo esquema que un visor tipo ArtworkArViewer: `src` = GLB, `ios-src` = USDZ, `ar-modes="webxr scene-viewer quick-look"`.

`Entity.write(to:)` de RealityKit (iOS 18+) escribe archivos `.reality`, no USDZ. Frame Art genera el USDZ con USDA + ZIP alineado a 64 bytes (especificación Pixar) y el GLB como glTF 2.0 binario con `KHR_materials_unlit`.

## Abrir en Xcode

1. Copia esta carpeta a un Mac.
2. Abre `FrameArt.xcodeproj`.
3. Elige un equipo de firma en el target **FrameArt**.
4. Bundle ID: `com.alancruzr.frameart`.
5. Ejecuta en un dispositivo real para AR. El simulador sirve para lista, alta y exportación de archivos.

Permisos (Info.plist generado):

- Cámara: fotografiar la obra y la sesión AR.
- Fototeca / selector de fotos: importar pinturas.

## Cómo abre el cliente la obra

**Opción A — un enlace (iPhone y Android)**  
Publica `web/` por HTTPS (GitHub Pages). El cliente abre esa URL:

- iPhone: botón *Ver en mi espacio* → Quick Look con `model.usdz`.
- Android: el mismo botón → WebXR o Scene Viewer con `model.glb`.

Coloca junto a `index.html` los archivos `model.usdz` y `model.glb` que exporta la app (Detalle de la obra → compartir). Query opcional:

```
https://alancruzr.github.io/frame-art/?title=Atardecer&glb=model.glb&usdz=model.usdz&placement=wall
```

**Opción B — archivo en el chat (sin página)**  
- iPhone: comparte el USDZ; Mensajes / WhatsApp / Archivos abren Quick Look.
- Android: comparte el GLB; se abre con Scene Viewer u otra app glTF.

La opción A es la que unifica iPhone y Android en **un** enlace.

## Siguiente paso

Publicar `web/` en GitHub Pages (HTTPS). En iOS, Safari solo dispara Quick Look con `rel="ar"` en páginas https. En Android, Scene Viewer necesita la URL https del GLB. Ejemplo futuro:

```html
<a rel="ar" href="obra.usdz">
  <img src="preview.jpg" alt="Ver en AR">
</a>
<model-viewer
  src="obra.glb"
  ios-src="obra.usdz"
  ar
  ar-modes="webxr scene-viewer quick-look"
  ar-placement="wall">
</model-viewer>
```

## Licencia

MIT. Copyright Alan Cruz.
