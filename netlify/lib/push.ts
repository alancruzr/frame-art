import { createHash, createPrivateKey, sign } from "node:crypto";
import { connect } from "node:http2";
import { getStore } from "@netlify/blobs";
import { envGet } from "./store";

/** Avisos al artista cuando un cliente abre su enlace. Sin datos personales del cliente. */

export const pushTokensStore = () => getStore({ name: "push-tokens", consistency: "strong" });
export const viewsStore = () => getStore({ name: "views", consistency: "strong" });

export interface PushToken { token: string; keyId: string; environment: "sandbox" | "production"; updatedAt: string }
export interface StudioTokens { tokens: PushToken[] }
export interface ViewRecord { count: number; lastNotifiedAt: number | null }

export const NOTIFY_WINDOW_MS = 30 * 60_000;
export const MAX_TOKENS_PER_STUDIO = 10;

export interface ApnsConfig { keyId: string; teamId: string; privateKey: string; topic: string; environment: "sandbox" | "production" }

export function apnsConfig(): ApnsConfig | null {
  const keyId = envGet("APNS_KEY_ID");
  const teamId = envGet("APNS_TEAM_ID") || envGet("APPLE_TEAM_ID");
  const raw = envGet("APNS_PRIVATE_KEY");
  if (!keyId || !teamId || !raw) return null;
  return {
    keyId,
    teamId,
    privateKey: raw.includes("\\n") ? raw.replace(/\\n/g, "\n") : raw,
    topic: envGet("APPLE_BUNDLE_ID") || "app.framestudio.ios",
    environment: (envGet("APNS_ENV") || "production") === "sandbox" ? "sandbox" : "production",
  };
}

/** JWT ES256 para APNs (token-based auth). Firma en formato JOSE (r||s, 64 bytes). */
export function apnsJwt(keyId: string, teamId: string, privateKeyPem: string, nowSec = Math.floor(Date.now() / 1000)): string {
  const header = Buffer.from(JSON.stringify({ alg: "ES256", kid: keyId })).toString("base64url");
  const claims = Buffer.from(JSON.stringify({ iss: teamId, iat: nowSec })).toString("base64url");
  const input = `${header}.${claims}`;
  const signature = sign("sha256", Buffer.from(input), { key: createPrivateKey(privateKeyPem), dsaEncoding: "ieee-p1363" });
  return `${input}.${signature.toString("base64url")}`;
}

let cachedJwt: { token: string; iat: number; keyId: string } | null = null;
function jwtFor(cfg: ApnsConfig): string {
  const now = Math.floor(Date.now() / 1000);
  // Apple acepta tokens de hasta 60 min y pide no regenerarlos más de una vez cada 20 min.
  if (!cachedJwt || cachedJwt.keyId !== cfg.keyId || now - cachedJwt.iat > 45 * 60) {
    cachedJwt = { token: apnsJwt(cfg.keyId, cfg.teamId, cfg.privateKey, now), iat: now, keyId: cfg.keyId };
  }
  return cachedJwt.token;
}

/** ¿Toca avisar? Como máximo un aviso por obra cada `windowMs`. */
export function shouldNotify(lastNotifiedAt: number | null, now: number, windowMs = NOTIFY_WINDOW_MS): boolean {
  return lastNotifiedAt === null || now - lastNotifiedAt >= windowMs;
}

const BOT_RE = /bot|crawl|spider|slurp|preview|facebookexternalhit|whatsapp|telegram|discord|slack|twitter|linkedin|embedly|headless|curl|wget|python|node-fetch|axios/i;

/** Los previsualizadores de enlaces (WhatsApp, iMessage, Slack…) y bots no cuentan como vista. */
export function isBot(userAgent: string | null): boolean {
  if (!userAgent) return true;
  return BOT_RE.test(userAgent);
}

/** Hash corto y no reversible para deduplicar sin guardar la IP. */
export function visitorKey(ip: string, userAgent: string, salt: string): string {
  return createHash("sha256").update(`${salt}|${ip}|${userAgent}`).digest("base64url").slice(0, 22);
}

export const isPushToken = (t: unknown): t is string => typeof t === "string" && /^[0-9a-f]{64,200}$/i.test(t);

export function upsertToken(record: StudioTokens | null, token: PushToken): StudioTokens {
  const others = (record?.tokens ?? []).filter((t) => t.token !== token.token && t.keyId !== token.keyId);
  return { tokens: [token, ...others].slice(0, MAX_TOKENS_PER_STUDIO) };
}

export function notificationPayload(studio: string, artwork: string, title: string | null) {
  const name = title && title.trim() ? `«${title.trim().slice(0, 80)}»` : "tu obra";
  return {
    aps: {
      alert: { title: "Tu cliente abrió la obra", body: `Alguien está viendo ${name} ahora.` },
      sound: "default",
      "thread-id": `${studio}/${artwork}`,
    },
    studio,
    artwork,
  };
}

/** Envía un push. Devuelve el status HTTP de APNs (0 si falló la conexión). */
export async function sendPush(cfg: ApnsConfig, token: PushToken, payload: unknown): Promise<number> {
  const host = (token.environment || cfg.environment) === "sandbox" ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";
  return new Promise((resolve) => {
    let client;
    try {
      client = connect(host);
    } catch {
      resolve(0);
      return;
    }
    client.on("error", () => resolve(0));
    const req = client.request({
      ":method": "POST",
      ":path": `/3/device/${token.token}`,
      authorization: `bearer ${jwtFor(cfg)}`,
      "apns-topic": cfg.topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    });
    let status = 0;
    req.on("response", (h) => { status = Number(h[":status"] || 0); });
    req.on("error", () => { client.close(); resolve(0); });
    req.on("end", () => { client.close(); resolve(status); });
    req.setTimeout(8000, () => { req.close(); client.close(); resolve(0); });
    req.end(JSON.stringify(payload));
    req.resume();
  });
}
