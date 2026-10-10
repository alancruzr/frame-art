import type { Config, Context } from "@netlify/functions";
import { authenticate, canWriteStudio, principalId } from "../lib/auth";
import { RATE, allow, checkContentLength, tooMany } from "../lib/limits";
import { artworksStore, blobKeys, isSlug } from "../lib/store";

async function readTarget(req: Request): Promise<{ studio: string; artwork: string }> {
  const url = new URL(req.url);
  let studio = url.searchParams.get("studio") || "";
  let artwork = url.searchParams.get("artwork") || "";
  const contentType = req.headers.get("content-type") || "";
  if (contentType.includes("application/json")) {
    try {
      const parsed = await req.json();
      if (typeof parsed.studio === "string") studio = parsed.studio;
      if (typeof parsed.artwork === "string") artwork = parsed.artwork;
    } catch {
      // ignore
    }
  } else if (contentType.includes("multipart/form-data")) {
    const form = await req.formData();
    studio = String(form.get("studio") || studio);
    artwork = String(form.get("artwork") || artwork);
  }
  return { studio: studio.trim(), artwork: artwork.trim() };
}

export default async (req: Request, context: Context) => {
  if (req.method !== "POST" && req.method !== "DELETE") {
    return new Response("Method Not Allowed", { status: 405, headers: { Allow: "POST, DELETE" } });
  }
  const principal = authenticate(req);
  if (principal instanceof Response) return principal;
  const ip = context.ip || "unknown";
  if (!(await allow(`unpublish-${principalId(principal, ip)}`, RATE.unpublishPerKeyHour))) return tooMany();
  const early = checkContentLength(req, 4 * 1024);
  if (early) return early;

  const { studio, artwork } = await readTarget(req);
  if (!isSlug(studio) || !isSlug(artwork)) {
    return new Response(JSON.stringify({ error: "invalid_slug" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!canWriteStudio(principal, studio)) {
    return new Response(JSON.stringify({ error: "studio_not_owned" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  const store = artworksStore();
  const keys = blobKeys(studio, artwork);
  await Promise.all(
    [keys.poster, keys.usdz, keys.glb, keys.meta].map(async (key) => {
      try {
        await store.delete(key);
      } catch {
        // missing keys are fine
      }
    }),
  );

  return new Response(null, { status: 204 });
};

export const config: Config = {
  path: "/api/unpublish",
  method: ["POST", "DELETE"],
};
