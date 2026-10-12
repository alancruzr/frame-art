import { createHash, generateKeyPairSync, sign } from "node:crypto";
import { describe, expect, it } from "vitest";
import { decodeCbor } from "../lib/cbor";
import { APPLE_APP_ATTEST_ROOT_CA, extractNonce, parseAuthData, verifyAssertion, verifyAttestation } from "../lib/appattest";
import { X509Certificate } from "node:crypto";

const app = { teamId: "ML4VB5PQ6H", bundleId: "app.framestudio.ios", env: "production" as const };
const sha = (...b: Buffer[]) => { const h = createHash("sha256"); b.forEach((x) => h.update(x)); return h.digest(); };

/** Codificador CBOR mínimo solo para los tests. */
function cbor(v: unknown): Buffer {
  const head = (major: number, len: number) => {
    if (len < 24) return Buffer.from([(major << 5) | len]);
    if (len < 256) return Buffer.from([(major << 5) | 24, len]);
    if (len < 65536) { const b = Buffer.alloc(3); b[0] = (major << 5) | 25; b.writeUInt16BE(len, 1); return b; }
    const b = Buffer.alloc(5); b[0] = (major << 5) | 26; b.writeUInt32BE(len, 1); return b;
  };
  if (Buffer.isBuffer(v)) return Buffer.concat([head(2, v.length), v]);
  if (typeof v === "string") { const s = Buffer.from(v); return Buffer.concat([head(3, s.length), s]); }
  if (typeof v === "number") return head(0, v);
  if (Array.isArray(v)) return Buffer.concat([head(4, v.length), ...v.map(cbor)]);
  const entries = Object.entries(v as Record<string, unknown>);
  return Buffer.concat([head(5, entries.length), ...entries.flatMap(([k, x]) => [cbor(k), cbor(x)])]);
}

function authData(counter: number): Buffer {
  const b = Buffer.alloc(37);
  sha(Buffer.from(`${app.teamId}.${app.bundleId}`)).copy(b, 0);
  b[32] = 0x40;
  b.writeUInt32BE(counter, 33);
  return b;
}

describe("cbor", () => {
  it("decodes maps, bytes, arrays", () => {
    const v = decodeCbor(cbor({ a: Buffer.from([1, 2]), b: ["x", 300] })) as Map<string, unknown>;
    expect(Buffer.from(v.get("a") as Uint8Array)).toEqual(Buffer.from([1, 2]));
    expect(v.get("b")).toEqual(["x", 300]);
  });
});

describe("assertion", () => {
  const { privateKey, publicKey } = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const pem = publicKey.export({ type: "spki", format: "pem" }) as string;

  const makeAssertion = (challenge: string, counter: number, key = privateKey) => {
    const ad = authData(counter);
    const nonce = sha(ad, sha(Buffer.from(challenge)));
    const signature = sign("sha256", nonce, key);
    return cbor({ signature, authenticatorData: ad }).toString("base64");
  };

  it("accepts a valid assertion and returns the new counter", () => {
    expect(verifyAssertion({ assertionB64: makeAssertion("nonce-1", 5), challenge: "nonce-1", publicKeyPem: pem, previousCounter: 4, app })).toBe(5);
  });
  it("rejects replayed counter, wrong challenge, wrong key, wrong app", () => {
    const a = makeAssertion("nonce-1", 5);
    expect(() => verifyAssertion({ assertionB64: a, challenge: "nonce-1", publicKeyPem: pem, previousCounter: 5, app })).toThrow(/replay/);
    expect(() => verifyAssertion({ assertionB64: a, challenge: "other", publicKeyPem: pem, previousCounter: 0, app })).toThrow(/signature/);
    const other = generateKeyPairSync("ec", { namedCurve: "prime256v1" }).privateKey;
    expect(() => verifyAssertion({ assertionB64: makeAssertion("n", 1, other), challenge: "n", publicKeyPem: pem, previousCounter: 0, app })).toThrow(/signature/);
    expect(() => verifyAssertion({ assertionB64: a, challenge: "nonce-1", publicKeyPem: pem, previousCounter: 0, app: { ...app, bundleId: "evil" } })).toThrow(/rpIdHash/);
  });
});

describe("attestation guards", () => {
  it("embeds the Apple root CA", () => {
    const root = new X509Certificate(APPLE_APP_ATTEST_ROOT_CA);
    expect(root.subject).toContain("Apple App Attestation Root CA");
    expect(root.fingerprint256).toBe("1C:B9:82:3B:A2:8B:A6:AD:2D:33:A0:06:94:1D:E2:AE:4F:51:3E:F1:D4:E8:31:B9:F7:E0:FA:7B:62:42:C9:32");
  });
  it("rejects garbage and wrong fmt", () => {
    expect(() => verifyAttestation({ keyId: "a", attestationB64: cbor({ fmt: "packed" }).toString("base64"), challenge: "n", app })).toThrow(/fmt/);
    expect(() => verifyAttestation({ keyId: "a", attestationB64: "AAAA", challenge: "n", app })).toThrow();
  });
  it("parses authData and nonce extension", () => {
    const ad = parseAuthData(authData(7));
    expect(ad.counter).toBe(7);
    const nonce = Buffer.alloc(32, 9);
    const fake = Buffer.concat([Buffer.from([0x30, 0x00]), Buffer.from([0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x08, 0x02]), Buffer.from([0x04, 0x26, 0x30, 0x24, 0xa1, 0x22, 0x04, 0x20]), nonce]);
    expect(extractNonce(fake)).toEqual(nonce);
  });
});
