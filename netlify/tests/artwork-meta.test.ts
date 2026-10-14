import { describe, expect, it } from "vitest";
import { cleanContact, contactHref, formatSize, parseMeta, quickLookFragment, sanitizeMeta } from "../lib/artwork-meta";

describe("artwork meta", () => {
  it("keeps valid fields and drops junk", () => {
    const m = sanitizeMeta({ title: " Luna ", artist: "Taller\u0007 Sol", widthCm: "60", heightCm: 2000, contact: "javascript:alert(1)" },
      { title: "x", createdAt: "t" });
    expect(m).toEqual({ title: "Luna", createdAt: "t", artist: "Taller Sol", widthCm: 60, heightCm: undefined, contact: undefined });
  });

  it("accepts email and phone contacts only", () => {
    expect(cleanContact("ana@estudio.mx")).toBe("ana@estudio.mx");
    expect(cleanContact("+52 55 1234 5678")).toBe("+52 55 1234 5678");
    expect(cleanContact("http://evil.example")).toBeUndefined();
    expect(cleanContact("123")).toBeUndefined();
  });

  it("builds mailto and wa.me links", () => {
    expect(contactHref("ana@estudio.mx", "Luna")).toMatch(/^mailto:ana%40estudio\.mx\?subject=/);
    expect(contactHref("+52 55 1234 5678", "Luna")).toMatch(/^https:\/\/wa\.me\/525512345678\?text=/);
  });

  it("formats sizes with inches", () => {
    expect(formatSize({ title: "a", createdAt: "", widthCm: 60, heightCm: 90 })).toBe("60 × 90 cm (23.6 × 35.4 in)");
  });

  it("adds the Quick Look banner only with contact", () => {
    expect(quickLookFragment({ title: "Luna", createdAt: "" })).toBe("#allowsContentScaling=0");
    const f = quickLookFragment({ title: "Luna", createdAt: "", artist: "Sol", widthCm: 60, heightCm: 90, contact: "a@b.co" });
    expect(f).toContain("callToAction=Me%20interesa");
    expect(f).toContain("checkoutTitle=Luna");
    expect(f).toContain("checkoutSubtitle=Sol%20%C2%B7%2060%20%C3%97%2090%20cm");
  });

  it("parses legacy meta", () => {
    expect(parseMeta('{"title":"Vieja"}', "slug").title).toBe("Vieja");
    expect(parseMeta("no-json", "slug").title).toBe("slug");
  });
});
