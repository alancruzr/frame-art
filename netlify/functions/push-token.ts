import type { Config, Context } from "@netlify/functions";
import { authenticate } from "../lib/auth";
import { allow, checkContentLength, tooMany } from "../lib/limits";
import { isPushToken, pushTokensStore, upsertToken, type StudioTokens } from "../lib/push";

/** POST /api/devices/push-token — guarda el token APNs del dispositivo autenticado (App Attest). */
export default async (req: Request, _context: Context) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  const principal = authenticate(req);
  if (principal instanceof Response) return principal;
  if (principal.kind !== "session") return Response.json({ error: "session_required" }, { status: 403 });
  const early = checkContentLength(req, 2048);
  if (early) return early;
  if (!(await allow(`push-token:${principal.session.keyId}`, 30))) return tooMany();

  let body: { token?: unknown; environment?: unknown };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "invalid_json" }, { status: 400 });
  }
  if (!isPushToken(body.token)) return Response.json({ error: "invalid_token" }, { status: 400 });
  const environment = body.environment === "sandbox" ? "sandbox" : "production";

  const store = pushTokensStore();
  const studio = principal.session.studio;
  const current = (await store.get(studio, { type: "json" })) as StudioTokens | null;
  const next = upsertToken(current, {
    token: body.token.toLowerCase(),
    keyId: principal.session.keyId,
    environment,
    updatedAt: new Date().toISOString(),
  });
  await store.setJSON(studio, next);
  return Response.json({ ok: true }, { headers: { "Cache-Control": "no-store" } });
};

export const config: Config = { path: "/api/devices/push-token", method: ["POST"] };
