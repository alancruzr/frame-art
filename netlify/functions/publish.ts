import type { Config, Context } from "@netlify/functions";
import { authenticate, canWriteStudio, principalId } from "../lib/auth";
import {
  MAX_ARTWORKS_PER_STUDIO,
  MAX_BYTES,
  MAX_TITLE,
  RATE,
  allow,
  checkContentLength,
  tooLarge,
  tooMany,
  validateBody,
} from "../lib/limits";
import { parseMeta, sanitizeMeta } from "../lib/artwork-meta";
import { artworksStore, blobKeys, isSlug, isStudioSlug, publicArtworkURL } from "../lib/store";

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

  const studio = url.searchParams.get("studio") || "";
  const artwork = url.searchParams.get("artwork") || "";
  const kind = url.searchParams.get("kind") || "";
  const title = url.searchParams.get("title") || "";
  const body = req.body ? await req.arrayBuffer() : null;
  return { studio, artwork, kind, title, body };
}

export default async (req: Request, context: Context) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405, headers: { Allow: "POST" } });
  }
  const principal = authenticate(req);
  if (principal instanceof Response) return principal;

  const ip = context.ip || "unknown";
  if (!(await allow(`publish-ip:${ip}`, RATE.publishPerIpHour))) return tooMany();
  if (!(await allow(`publish-${principalId(principal, ip)}`, RATE.publishPerKeyHour))) return tooMany();

  // Rechazo temprano por Content-Length (multipart añade algo de overhead).
  const hintedKind = (new URL(req.url).searchParams.get("kind") || "").toLowerCase();
  const early = checkContentLength(req, (MAX_BYTES[hintedKind] ?? MAX_BYTES.usdz) + 16 * 1024);
  if (early) return early;

  const payload = await readPayload(req);
  const studio = payload.studio.trim();
  const artwork = payload.artwork.trim();
  const kind = payload.kind.trim().toLowerCase();
  const title = payload.title.trim().slice(0, MAX_TITLE);

  if (!isStudioSlug(studio) || !isSlug(artwork)) {
    return json(400, { error: "invalid_slug" });
  }
  if (!KINDS.has(kind)) {
    return json(400, { error: "invalid_kind" });
  }
  if (!canWriteStudio(principal, studio)) {
    return json(403, { error: "studio_not_owned" });
  }
  if (payload.body && payload.body.byteLength > 0) {
    const invalid = validateBody(kind, payload.body);
    if (invalid === "payload_too_large") return tooLarge(MAX_BYTES[kind]);
    if (invalid) return json(400, { error: invalid });
  }

  const keys = blobKeys(studio, artwork);
  const key =
    kind === "poster" ? keys.poster :
    kind === "usdz" ? keys.usdz :
    kind === "glb" ? keys.glb :
    keys.meta;

  const store = artworksStore();
  const contentType = CONTENT_TYPE[kind];

  // Cuota por estudio: solo cuenta al crear una obra nueva.
  const isNewArtwork = !(await store.getMetadata(keys.meta)) && !(await store.getMetadata(keys.usdz));
  if (isNewArtwork) {
    const { directories } = await store.list({ prefix: `${studio}/`, directories: true });
    if (directories.length >= MAX_ARTWORKS_PER_STUDIO) {
      return json(403, { error: "studio_quota_exceeded", max: MAX_ARTWORKS_PER_STUDIO });
    }
  }

  if (kind === "meta") {
    let raw: unknown = {};
    if (payload.body && payload.body.byteLength > 0) {
      try {
        raw = JSON.parse(new TextDecoder().decode(payload.body));
      } catch {
        // raw body is not JSON; keep title from query
      }
    }
    const meta = sanitizeMeta(raw, { title: title || artwork, createdAt: new Date().toISOString() });
    await store.set(key, JSON.stringify(meta), { metadata: { contentType } });
  } else {
    if (!payload.body || payload.body.byteLength === 0) {
      return json(400, { error: "missing_file" });
    }
    await store.set(key, payload.body, { metadata: { contentType } });
    if (title) {
      const existing = await store.get(keys.meta, { type: "text" });
      const meta = existing ? parseMeta(existing, title) : sanitizeMeta({}, { title, createdAt: new Date().toISOString() });
      meta.title = title;
      await store.set(keys.meta, JSON.stringify(meta), {
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
