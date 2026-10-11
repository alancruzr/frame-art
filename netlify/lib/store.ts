declare const Netlify: { env: { get(name: string): string | undefined } };

import { getStore } from "@netlify/blobs";

export const SITE_ORIGIN = "https://frame-studio.netlify.app";

export function artworksStore() {
  return getStore({ name: "artworks", consistency: "strong" as const });
}

export const SLUG_RE = /^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$/;

export function isSlug(value: string): boolean {
  return typeof value === "string" && value.length <= 64 && SLUG_RE.test(value);
}

export function blobKeys(studio: string, artwork: string) {
  const prefix = `${studio}/${artwork}`;
  return {
    poster: `${prefix}/poster.jpg`,
    usdz: `${prefix}/model.usdz`,
    glb: `${prefix}/model.glb`,
    meta: `${prefix}/meta.json`,
  };
}

export function envGet(name: string): string | undefined {
  try {
    const fromNetlify = Netlify.env.get(name);
    if (fromNetlify) return fromNetlify;
  } catch {
    // not running in a Netlify runtime that exposes Netlify.env
  }
  return process.env[name];
}

export function unauthorized(): Response {
  return new Response("Unauthorized", { status: 401 });
}


export function publicArtworkURL(studio: string, artwork: string): string {
  return `${SITE_ORIGIN}/${studio}/${artwork}/`;
}

/** Slugs de estudio reservados para páginas estáticas y rutas del sitio. */
export const RESERVED_STUDIOS = new Set(["api", "assets", "privacy", "terms", "support", "well-known", "index", "admin", "static"]);

export function isStudioSlug(value: string): boolean {
  return isSlug(value) && !RESERVED_STUDIOS.has(value);
}
