import { createHmac, timingSafeEqual } from "node:crypto";

/** JWT HS256 mínimo (sin dependencias). */
export interface Session {
  keyId: string;
  studio: string;
}

const AUD = "frame-studio-publish";
const b64url = (b: Buffer | string) => Buffer.from(b).toString("base64url");

export function issueSession(s: Session, secret: string, ttlSeconds = 15 * 60, nowSec = Math.floor(Date.now() / 1000)): string {
  if (secret.length < 32) throw new Error("session secret too short");
  const header = b64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = b64url(JSON.stringify({ ...s, aud: AUD, iat: nowSec, exp: nowSec + ttlSeconds }));
  const sig = createHmac("sha256", secret).update(`${header}.${payload}`).digest("base64url");
  return `${header}.${payload}.${sig}`;
}

export function verifySession(token: string, secret: string, nowSec = Math.floor(Date.now() / 1000)): Session | null {
  if (!secret || secret.length < 32) return null;
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const [h, p, sig] = parts;
  const expected = createHmac("sha256", secret).update(`${h}.${p}`).digest();
  const given = Buffer.from(sig, "base64url");
  if (given.length !== expected.length || !timingSafeEqual(given, expected)) return null;
  try {
    const header = JSON.parse(Buffer.from(h, "base64url").toString("utf8"));
    if (header.alg !== "HS256") return null;
    const claims = JSON.parse(Buffer.from(p, "base64url").toString("utf8"));
    if (claims.aud !== AUD || typeof claims.exp !== "number" || claims.exp < nowSec) return null;
    if (typeof claims.keyId !== "string" || typeof claims.studio !== "string") return null;
    return { keyId: claims.keyId, studio: claims.studio };
  } catch {
    return null;
  }
}

export const looksLikeJwt = (t: string) => t.split(".").length === 3;
