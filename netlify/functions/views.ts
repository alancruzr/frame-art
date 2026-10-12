import type { Config, Context } from "@netlify/functions";
import { authenticate } from "../lib/auth";
import { allow, checkContentLength } from "../lib/limits";
import {
  apnsConfig, isBot, notificationPayload, pushTokensStore, sendPush, shouldNotify, viewsStore, visitorKey,
  type StudioTokens, type ViewRecord,
} from "../lib/push";
import { artworksStore, blobKeys, envGet, isSlug } from "../lib/store";

const ok = () => new Response(null, { status: 204, headers: { "Cache-Control": "no-store" } });

/**
 * POST /api/views {studio, artwork} — beacon del visor. Cuenta una vista por visitante (hash
 * efímero de IP+UA, no se guarda) cada 30 min y avisa al artista como máximo una vez cada 30 min por obra.
 * GET /api/views?studio=&artwork= — conteo, solo para el dueño (sesión App Attest).
 */
export default async (req: Request, context: Context) => {
  if (req.method === "GET") return getCount(req);
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  if (checkContentLength(req, 1024)) return ok();
  const ua = req.headers.get("user-agent");
  if (isBot(ua)) return ok();

  let studio = "", artwork = "", owner = false;
  try {
    const body = await req.json();
    studio = String(body.studio || "");
    artwork = String(body.artwork || "");
    owner = body.owner === true;
  } catch {
    return ok();
  }
  // El visor marca `owner` si ese navegador publicó o abrió la obra desde la app del artista.
  if (owner || !isSlug(studio) || !isSlug(artwork)) return ok();

  const ip = context.ip || "unknown";
  if (!(await allow(`views-ip:${visitorKey(ip, "", "ip")}`, 120))) return ok();
  const visitor = visitorKey(ip, ua || "", envGet("FRAME_STUDIO_SESSION_SECRET") || "frame-studio");
  if (!(await allow(`view:${studio}/${artwork}:${visitor}`, 1, 1800))) return ok();

  const meta = (await artworksStore().get(blobKeys(studio, artwork).meta, { type: "json" })) as { title?: string } | null;
  if (!meta) return ok();

  const key = `${studio}/${artwork}`;
  const views = viewsStore();
  const record = ((await views.get(key, { type: "json" })) as ViewRecord | null) ?? { count: 0, lastNotifiedAt: null };
  record.count += 1;
  const now = Date.now();
  const cfg = apnsConfig();
  const notify = cfg !== null && shouldNotify(record.lastNotifiedAt, now);
  if (notify) record.lastNotifiedAt = now;
  await views.setJSON(key, record);

  if (notify && cfg) {
    const tokensStore = pushTokensStore();
    const tokens = (await tokensStore.get(studio, { type: "json" })) as StudioTokens | null;
    if (tokens?.tokens.length) {
      const payload = notificationPayload(studio, artwork, meta.title ?? null);
      const results = await Promise.all(tokens.tokens.map((t) => sendPush(cfg, t, payload)));
      const alive = tokens.tokens.filter((_, i) => results[i] !== 410 && results[i] !== 400);
      if (alive.length !== tokens.tokens.length) await tokensStore.setJSON(studio, { tokens: alive });
    }
  }
  return ok();
};

async function getCount(req: Request): Promise<Response> {
  const principal = authenticate(req);
  if (principal instanceof Response) return principal;
  const url = new URL(req.url);
  const studio = url.searchParams.get("studio") || "";
  const artwork = url.searchParams.get("artwork") || "";
  if (!isSlug(studio) || !isSlug(artwork)) return Response.json({ error: "invalid_slug" }, { status: 400 });
  if (principal.kind === "session" && principal.session.studio !== studio) return Response.json({ error: "forbidden" }, { status: 403 });
  const record = (await viewsStore().get(`${studio}/${artwork}`, { type: "json" })) as ViewRecord | null;
  return Response.json({ count: record?.count ?? 0 }, { headers: { "Cache-Control": "no-store" } });
}

export const config: Config = { path: "/api/views", method: ["GET", "POST"] };
