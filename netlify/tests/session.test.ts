import { describe, expect, it } from "vitest";
import { issueSession, verifySession } from "../lib/session";

const SECRET = "x".repeat(48);

describe("session JWT", () => {
  it("round-trips", () => {
    const t = issueSession({ keyId: "k1", studio: "taller" }, SECRET);
    expect(verifySession(t, SECRET)).toEqual({ keyId: "k1", studio: "taller" });
  });
  it("rejects wrong secret, tampering and expiry", () => {
    const t = issueSession({ keyId: "k1", studio: "taller" }, SECRET, 60, 1000);
    expect(verifySession(t, "y".repeat(48), 1001)).toBeNull();
    const [h, p, s] = t.split(".");
    const forged = Buffer.from(JSON.stringify({ keyId: "k1", studio: "otro", aud: "frame-studio-publish", exp: 9e9 })).toString("base64url");
    expect(verifySession(`${h}.${forged}.${s}`, SECRET, 1001)).toBeNull();
    expect(verifySession(t, SECRET, 2000)).toBeNull();
    expect(verifySession(`${h}.${p}.${s}`, SECRET, 1001)).not.toBeNull();
  });
  it("refuses short secrets", () => {
    expect(() => issueSession({ keyId: "k", studio: "s" }, "short")).toThrow();
    expect(verifySession("a.b.c", "short")).toBeNull();
  });
});
