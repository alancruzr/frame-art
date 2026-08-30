import type { Config, Context } from "@netlify/functions";
import {
  artworksStore,
  blobKeys,
  isSlug,
  publicArtworkURL,
  requireBearer,
} from "../lib/store";

const KINDS = new Set(["poster", "usdz", "glb", "meta"]);

const CONTENT_TYPE: Record<string, string> = {
  poster: "image/jpeg",
  usdz: "model/vnd.usdz+zip",
  glb: "model/gltf-binary",
  meta: "application/json",
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function readPayload(req: Request): Promise<{
  studio: string;
  artwork: string;
  kind: string;
  title: string;
  body: ArrayBuffer | null;
}> {
  const url = new URL(req.url);
  const contentType = req.headers.get("content-type") || "";

  if (contentType.includes("multipart/form-data")) {
    const form = await req.formData();
    const studio = String(form.get("studio") || url.searchParams.get("studio") || "");
    const artwork = String(form.get("artwork") || url.searchParams.get("artwork") || "");
    const kind = String(form.get("kind") || url.searchParams.get("kind") || "");
    const title = String(form.get("title") || url.searchParams.get("title") || "");
    const file = form.get("file");
    let body: ArrayBuffer | null = null;
    if (file instanceof Blob) {
      body = await file.arrayBuffer();
    } else if (typeof file === "string" && file.length > 0) {
      body = new TextEncoder().encode(file).buffer;
    }
    return { studio, artwork, kind, title, body };
  }

  const studio =
    url.searchParams.get("studio") ||
    req.headers.get("x-studio") ||
    "";
  const artwork =
    url.searchParams.get("artwork") ||
    req.headers.get("x-artwork") ||
    "";
  const kind = url.searchParams.get("kind") || req.headers.get("x-kind") || "";
  const title = url.searchParams.get("title") || req.headers.get("x-title") || "";
  const body = req.body ? await req.arrayBuffer() : null;
  return { studio, artwork, kind, title, body };
}

export default async (req: Request, _context: Context) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405, headers: { Allow: "POST" } });
  }
  const denied = requireBearer(req);
  if (denied) return denied;

  const payload = await readPayload(req);
  const studio = payload.studio.trim();
  const artwork = payload.artwork.trim();
  const kind = payload.kind.trim().toLowerCase();
  const title = payload.title.trim();

  if (!isSlug(studio) || !isSlug(artwork)) {
    return json(400, { error: "invalid_slug" });
  }
  if (!KINDS.has(kind)) {
    return json(400, { error: "invalid_kind" });
  }

  const keys = blobKeys(studio, artwork);
  const key =
    kind === "poster" ? keys.poster :
    kind === "usdz" ? keys.usdz :
    kind === "glb" ? keys.glb :
    keys.meta;

  const store = artworksStore();
  const contentType = CONTENT_TYPE[kind];

  if (kind === "meta") {
    let createdAt = new Date().toISOString();
    let metaTitle = title;
    if (payload.body && payload.body.byteLength > 0) {
      try {
        const parsed = JSON.parse(new TextDecoder().decode(payload.body));
        if (typeof parsed.title === "string" && parsed.title.trim()) {
          metaTitle = parsed.title.trim();
        }
        if (typeof parsed.createdAt === "string" && parsed.createdAt.trim()) {
          createdAt = parsed.createdAt.trim();
        }
      } catch {
        // raw body is not JSON; keep title from query
      }
    }
    const meta = JSON.stringify({ title: metaTitle || artwork, createdAt });
    await store.set(key, meta, { metadata: { contentType } });
  } else {
    if (!payload.body || payload.body.byteLength === 0) {
      return json(400, { error: "missing_file" });
    }
    await store.set(key, payload.body, { metadata: { contentType } });
    if (title) {
      const existing = await store.get(keys.meta, { type: "text" });
      let createdAt = new Date().toISOString();
      if (existing) {
        try {
          const parsed = JSON.parse(existing);
          if (typeof parsed.createdAt === "string") createdAt = parsed.createdAt;
        } catch {
          // replace
        }
      }
      await store.set(keys.meta, JSON.stringify({ title, createdAt }), {
        metadata: { contentType: CONTENT_TYPE.meta },
      });
    }
  }

  return json(200, { url: publicArtworkURL(studio, artwork) });
};

export const config: Config = {
  path: "/api/publish",
  method: "POST",
};
