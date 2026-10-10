import { getStore } from "@netlify/blobs";

/** Límites por tipo de archivo. Las Functions síncronas de Netlify aceptan ~6 MB de cuerpo. */
export const MAX_BYTES: Record<string, number> = {
  poster: 3 * 1024 * 1024,
  usdz: 6 * 1024 * 1024,
  glb: 6 * 1024 * 1024,
  meta: 4 * 1024,
};
export const MAX_TITLE = 120;
export const MAX_ARTWORKS_PER_STUDIO = 200;

export const RATE = {
  publishPerIpHour: 120,
  publishPerKeyHour: 60,
  unpublishPerKeyHour: 30,
  authPerIpHour: 20,
};

const json = (status: number, body: unknown, headers: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", ...headers } });

export const tooMany = (retryAfter = 3600) => json(429, { error: "rate_limited" }, { "Retry-After": String(retryAfter) });
export const tooLarge = (max: number) => json(413, { error: "payload_too_large", max });

/** Rechaza antes de leer el cuerpo si Content-Length excede el máximo. */
export function checkContentLength(req: Request, max: number): Response | null {
  const raw = req.headers.get("content-length");
  if (raw === null) return null;
  const len = Number(raw);
  if (Number.isFinite(len) && len > max) return tooLarge(max);
  return null;
}

/** Ventana fija con contador en Netlify Blobs. No es atómico: tolera un pequeño exceso. */
export async function allow(bucket: string, limit: number, windowSec = 3600): Promise<boolean> {
  const window = Math.floor(Date.now() / 1000 / windowSec);
  const store = getStore({ name: "ratelimits", consistency: "strong" });
  const key = `${bucket.replace(/[^a-zA-Z0-9:._-]/g, "_")}/${window}`;
  const current = Number((await store.get(key, { type: "text" })) ?? "0");
  if (current >= limit) return false;
  await store.set(key, String(current + 1));
  return true;
}

const u8 = (b: ArrayBuffer) => new Uint8Array(b);
export const isZip = (b: ArrayBuffer) => { const a = u8(b); return a.length >= 4 && a[0] === 0x50 && a[1] === 0x4b && a[2] === 0x03 && a[3] === 0x04; };
export const isGlb = (b: ArrayBuffer) => { const a = u8(b); return a.length >= 12 && a[0] === 0x67 && a[1] === 0x6c && a[2] === 0x54 && a[3] === 0x46; };
export const isJpeg = (b: ArrayBuffer) => { const a = u8(b); return a.length >= 3 && a[0] === 0xff && a[1] === 0xd8 && a[2] === 0xff; };

/** Valida tamaño y tipo real del archivo. Devuelve un código de error o null. */
export function validateBody(kind: string, body: ArrayBuffer): string | null {
  const max = MAX_BYTES[kind];
  if (max === undefined) return "invalid_kind";
  if (body.byteLength > max) return "payload_too_large";
  if (kind === "usdz" && !isZip(body)) return "invalid_usdz";
  if (kind === "glb" && !isGlb(body)) return "invalid_glb";
  if (kind === "poster" && !isJpeg(body)) return "invalid_jpeg";
  return null;
}
