import { timingSafeEqual } from "node:crypto";
import { envGet, unauthorized } from "./store";
import { looksLikeJwt, verifySession, type Session } from "./session";

export type Principal =
  | { kind: "session"; session: Session }
  | { kind: "legacy" };

/**
 * Autenticación de publish/unpublish.
 * - Token de sesión (App Attest) si FRAME_STUDIO_SESSION_SECRET está configurado.
 * - Clave compartida LEGACY (FRAME_STUDIO_PUBLISH_KEY) mientras FRAME_STUDIO_LEGACY_KEY_ENABLED != "false".
 *   Por defecto sigue activa para no romper builds existentes; apágala cuando todos usen App Attest.
 */
export function authenticate(req: Request): Principal | Response {
  const header = req.headers.get("authorization") || "";
  if (!header.startsWith("Bearer ")) return unauthorized();
  const token = header.slice(7);

  const secret = envGet("FRAME_STUDIO_SESSION_SECRET") || "";
  if (secret && looksLikeJwt(token)) {
    const session = verifySession(token, secret);
    return session ? { kind: "session", session } : unauthorized();
  }

  if (legacyEnabled()) {
    const expected = envGet("FRAME_STUDIO_PUBLISH_KEY") || "";
    if (expected && safeEqual(token, expected)) return { kind: "legacy" };
  }
  return unauthorized();
}

export function legacyEnabled(): boolean {
  return (envGet("FRAME_STUDIO_LEGACY_KEY_ENABLED") || "true").toLowerCase() !== "false";
}

export function principalId(p: Principal, ip: string): string {
  return p.kind === "session" ? `key:${p.session.keyId}` : `legacy:${ip}`;
}

/** Con sesión, solo se puede escribir en el estudio propio. */
export function canWriteStudio(p: Principal, studio: string): boolean {
  return p.kind === "legacy" || p.session.studio === studio;
}

function safeEqual(a: string, b: string): boolean {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}
