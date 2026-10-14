import { createPublicKey, generateKeyPairSync, verify } from "node:crypto";
import { describe, expect, it } from "vitest";
import { apnsJwt, isBot, isPushToken, notificationPayload, shouldNotify, upsertToken, visitorKey, NOTIFY_WINDOW_MS } from "../lib/push";

describe("shouldNotify (throttle)", () => {
  it("notifies the first time", () => expect(shouldNotify(null, 1_000)).toBe(true));
  it("dedupes inside the 30 min window", () => {
    expect(shouldNotify(0, NOTIFY_WINDOW_MS - 1)).toBe(false);
    expect(shouldNotify(0, 60_000)).toBe(false);
  });
  it("notifies again after the window", () => expect(shouldNotify(0, NOTIFY_WINDOW_MS)).toBe(true));
});

describe("isBot", () => {
  it("filters link previewers and bots", () => {
    expect(isBot(null)).toBe(true);
    expect(isBot("WhatsApp/2.23.20 A")).toBe(true);
    expect(isBot("facebookexternalhit/1.1")).toBe(true);
    expect(isBot("Mozilla/5.0 (compatible; Googlebot/2.1)")).toBe(true);
    expect(isBot("curl/8.4.0")).toBe(true);
  });
  it("lets real browsers through", () => {
    expect(isBot("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1")).toBe(false);
  });
});

describe("visitorKey", () => {
  it("is stable, salted and does not contain the IP", () => {
    const a = visitorKey("203.0.113.9", "UA", "s1");
    expect(a).toBe(visitorKey("203.0.113.9", "UA", "s1"));
    expect(a).not.toBe(visitorKey("203.0.113.9", "UA", "s2"));
    expect(a).not.toContain("203");
  });
});

describe("apnsJwt (ES256)", () => {
  it("signs a verifiable JOSE token", () => {
    const { privateKey } = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
    const pem = privateKey.export({ type: "pkcs8", format: "pem" }).toString();
    const jwt = apnsJwt("ABC123DEFG", "ML4VB5PQ6H", pem, 1_700_000_000);
    const [h, c, s] = jwt.split(".");
    expect(JSON.parse(Buffer.from(h, "base64url").toString())).toEqual({ alg: "ES256", kid: "ABC123DEFG" });
    expect(JSON.parse(Buffer.from(c, "base64url").toString())).toEqual({ iss: "ML4VB5PQ6H", iat: 1_700_000_000 });
    const sig = Buffer.from(s, "base64url");
    expect(sig.length).toBe(64);
    const ok = verify("sha256", Buffer.from(`${h}.${c}`), { key: createPublicKey(pem), dsaEncoding: "ieee-p1363" }, sig);
    expect(ok).toBe(true);
  });
});

describe("tokens + payload", () => {
  it("validates hex tokens", () => {
    expect(isPushToken("a".repeat(64))).toBe(true);
    expect(isPushToken("zz")).toBe(false);
  });
  it("upserts per device and caps the list", () => {
    const t = (n: number, key = `k${n}`) => ({ token: n.toString(16).padStart(64, "0"), keyId: key, environment: "production" as const, updatedAt: "" });
    let r = upsertToken(null, t(1));
    r = upsertToken(r, t(2, "k1"));
    expect(r.tokens).toHaveLength(1);
    expect(r.tokens[0].token).toBe(t(2).token);
    for (let i = 3; i < 20; i++) r = upsertToken(r, t(i));
    expect(r.tokens.length).toBeLessThanOrEqual(10);
  });
  it("builds a deep-linkable payload without client data", () => {
    const p = notificationPayload("taller-luna", "mar-1234", "Mar");
    expect(p.studio).toBe("taller-luna");
    expect(p.artwork).toBe("mar-1234");
    expect(JSON.stringify(p)).not.toMatch(/ip|user-agent/i);
  });
});
