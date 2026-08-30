import type { Config, Context } from "@netlify/functions";
import { artworksStore, blobKeys, isSlug, SITE_ORIGIN } from "../lib/store";
import { viewerHTML } from "../lib/viewer-html";

const TYPES: Record<string, string> = {
  "poster.jpg": "image/jpeg",
  "model.usdz": "model/vnd.usdz+zip",
  "model.glb": "model/gltf-binary",
};

function notFound(): Response {
  return new Response("Not found", { status: 404, headers: { "Content-Type": "text/plain; charset=utf-8" } });
}

export default async (req: Request, context: Context) => {
  const url = new URL(req.url);
  const parts = url.pathname.split("/").filter(Boolean);
  const studio = (context.params.studio || parts[0] || "").trim();
  const artwork = (context.params.artwork || parts[1] || "").trim();
  const file = (parts[2] || "").trim();

  if (!isSlug(studio) || !isSlug(artwork)) {
    return notFound();
  }

  const store = artworksStore();
  const keys = blobKeys(studio, artwork);

  if (!file || file === "index.html") {
    const metaText = await store.get(keys.meta, { type: "text" });
    const posterMeta = await store.getMetadata(keys.poster);
    if (!metaText && !posterMeta) {
      return notFound();
    }
    let title = artwork;
    if (metaText) {
      try {
        const parsed = JSON.parse(metaText);
        if (typeof parsed.title === "string" && parsed.title.trim()) {
          title = parsed.title.trim();
        }
      } catch {
        // keep slug
      }
    }
    const posterAbs = `${SITE_ORIGIN}/${studio}/${artwork}/poster.jpg`;
    const html = viewerHTML(title, posterAbs);
    return new Response(html, {
      status: 200,
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "public, max-age=0, must-revalidate",
      },
    });
  }

  const kind = file === "poster.jpg" ? "poster" : file === "model.usdz" ? "usdz" : file === "model.glb" ? "glb" : "";
  if (!kind) {
    return notFound();
  }

  const key = kind === "poster" ? keys.poster : kind === "usdz" ? keys.usdz : keys.glb;
  const entry = await store.getWithMetadata(key, { type: "arrayBuffer" });
  if (!entry || !entry.data) {
    return notFound();
  }
  const contentType =
    (typeof entry.metadata?.contentType === "string" && entry.metadata.contentType) ||
    TYPES[file] ||
    "application/octet-stream";

  return new Response(entry.data, {
    status: 200,
    headers: {
      "Content-Type": contentType,
      "Cache-Control": "public, max-age=0, must-revalidate",
    },
  });
};

export const config: Config = {
  path: [
    "/:studio/:artwork",
    "/:studio/:artwork/",
    "/:studio/:artwork/index.html",
    "/:studio/:artwork/model.usdz",
    "/:studio/:artwork/model.glb",
    "/:studio/:artwork/poster.jpg",
  ],
  excludedPath: [
    "/",
    "/index.html",
    "/o/*",
    "/api/*",
    "/model.usdz",
    "/model.glb",
    "/poster.jpg",
    "/poster.png",
    "/apple-app-site-association",
    "/.well-known/*",
  ],
  preferStatic: true,
  method: "GET",
};
