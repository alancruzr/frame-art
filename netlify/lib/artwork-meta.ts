// Metadatos públicos de una obra (ficha del cliente). Todo es opcional salvo el título.
export const MAX_TITLE = 120;
const MAX_ARTIST = 80;
const MAX_CONTACT = 120;

export interface ArtworkMeta {
  title: string;
  createdAt: string;
  artist?: string;
  widthCm?: number;
  heightCm?: number;
  /** Correo o teléfono (WhatsApp) tal como lo escribió el artista, ya validado. */
  contact?: string;
}

const EMAIL_RE = /^[^\s@<>"']{1,64}@[^\s@<>"']{1,190}\.[a-z]{2,24}$/i;

function cleanText(value: unknown, max: number): string | undefined {
  if (typeof value !== "string") return undefined;
  const v = value.replace(/[\u0000-\u001f\u007f]/g, "").trim().slice(0, max);
  return v || undefined;
}

function cleanSize(value: unknown): number | undefined {
  const n = typeof value === "number" ? value : typeof value === "string" ? Number(value) : NaN;
  return Number.isFinite(n) && n >= 1 && n <= 1000 ? Math.round(n * 10) / 10 : undefined;
}

export function cleanContact(value: unknown): string | undefined {
  const v = cleanText(value, MAX_CONTACT);
  if (!v) return undefined;
  if (EMAIL_RE.test(v)) return v;
  const digits = v.replace(/[^\d]/g, "");
  if (/^\+?[\d\s().-]+$/.test(v) && digits.length >= 8 && digits.length <= 15) return v;
  return undefined;
}

/** Enlace del botón "Me interesa": mailto o WhatsApp (wa.me). */
export function contactHref(contact: string | undefined, title: string): string | undefined {
  if (!contact) return undefined;
  const text = `Hola, me interesa la obra "${title}" que vi en Frame Studio.`;
  if (contact.includes("@")) {
    return `mailto:${encodeURIComponent(contact)}?subject=${encodeURIComponent(`Me interesa: ${title}`)}&body=${encodeURIComponent(text)}`;
  }
  return `https://wa.me/${contact.replace(/[^\d]/g, "")}?text=${encodeURIComponent(text)}`;
}

export function sanitizeMeta(raw: unknown, fallback: { title: string; createdAt: string }): ArtworkMeta {
  const r = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  return {
    title: cleanText(r.title, MAX_TITLE) ?? fallback.title.slice(0, MAX_TITLE),
    createdAt: cleanText(r.createdAt, 40) ?? fallback.createdAt,
    artist: cleanText(r.artist, MAX_ARTIST),
    widthCm: cleanSize(r.widthCm),
    heightCm: cleanSize(r.heightCm),
    contact: cleanContact(r.contact),
  };
}

export function parseMeta(text: string | null | undefined, fallbackTitle: string): ArtworkMeta {
  let raw: unknown = {};
  if (text) {
    try { raw = JSON.parse(text); } catch { raw = {}; }
  }
  return sanitizeMeta(raw, { title: fallbackTitle, createdAt: new Date(0).toISOString() });
}

export function formatSize(meta: ArtworkMeta): string | undefined {
  if (!meta.widthCm || !meta.heightCm) return undefined;
  const fmt = (n: number) => (Number.isInteger(n) ? String(n) : n.toFixed(1));
  const inch = (n: number) => (n / 2.54).toFixed(1).replace(/\.0$/, "");
  return `${fmt(meta.widthCm)} × ${fmt(meta.heightCm)} cm (${inch(meta.widthCm)} × ${inch(meta.heightCm)} in)`;
}

/** Fragmento de AR Quick Look (allowsContentScaling + banner con callToAction). */
export function quickLookFragment(meta: ArtworkMeta): string {
  const parts = ["allowsContentScaling=0"];
  if (meta.contact) {
    parts.push(`callToAction=${encodeURIComponent("Me interesa")}`);
    parts.push(`checkoutTitle=${encodeURIComponent(meta.title)}`);
    const sub = [meta.artist, formatSize(meta)?.split(" (")[0]].filter(Boolean).join(" · ");
    if (sub) parts.push(`checkoutSubtitle=${encodeURIComponent(sub)}`);
  }
  return "#" + parts.join("&");
}
