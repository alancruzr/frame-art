import { X509Certificate, createHash, createPublicKey, verify as cryptoVerify, type KeyObject } from "node:crypto";
import { decodeCbor, mapGet } from "./cbor";

/** Apple App Attestation Root CA (https://www.apple.com/certificateauthority/Apple_App_Attestation_Root_CA.pem).
 *  SHA-256: 1C:B9:82:3B:A2:8B:A6:AD:2D:33:A0:06:94:1D:E2:AE:4F:51:3E:F1:D4:E8:31:B9:F7:E0:FA:7B:62:42:C9:32 */
export const APPLE_APP_ATTEST_ROOT_CA = `-----BEGIN CERTIFICATE-----
MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
Fw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
Yen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
oyFraWVIyd/dganmrduC1bmTBGwD
-----END CERTIFICATE-----`;

const NONCE_OID = Buffer.from([0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x08, 0x02]);
const AAGUID_DEV = Buffer.from("appattestdevelop", "ascii");
const AAGUID_PROD = Buffer.concat([Buffer.from("appattest", "ascii"), Buffer.alloc(7)]);

export type AttestEnv = "development" | "production";

export interface AppIdentity {
  teamId: string;
  bundleId: string;
  env: AttestEnv;
  /** Permite también el entorno de desarrollo cuando env = production (builds de Xcode). */
  allowDevelopment?: boolean;
}

const sha256 = (...parts: Uint8Array[]) => {
  const h = createHash("sha256");
  for (const p of parts) h.update(p);
  return h.digest();
};

export interface AuthData {
  rpIdHash: Buffer;
  flags: number;
  counter: number;
  aaguid?: Buffer;
  credentialId?: Buffer;
}

export function parseAuthData(data: Uint8Array): AuthData {
  const b = Buffer.from(data);
  if (b.length < 37) throw new Error("authData too short");
  const out: AuthData = { rpIdHash: b.subarray(0, 32), flags: b[32], counter: b.readUInt32BE(33) };
  if (b.length >= 55) {
    out.aaguid = b.subarray(37, 53);
    const len = b.readUInt16BE(53);
    out.credentialId = b.subarray(55, 55 + len);
  }
  return out;
}

/** Extrae el nonce de la extensión 1.2.840.113635.100.8.2 del certificado hoja. */
export function extractNonce(certDer: Buffer): Buffer {
  const at = certDer.indexOf(NONCE_OID);
  if (at < 0) throw new Error("nonce extension missing");
  const window = certDer.subarray(at + NONCE_OID.length, at + NONCE_OID.length + 32);
  const marker = window.indexOf(Buffer.from([0x04, 0x20]));
  if (marker < 0) throw new Error("nonce octet string missing");
  const start = at + NONCE_OID.length + marker + 2;
  return certDer.subarray(start, start + 32);
}

function uncompressedPoint(key: KeyObject): Buffer {
  const spki = key.export({ type: "spki", format: "der" }) as Buffer;
  return spki.subarray(spki.length - 65);
}

export interface AttestationResult {
  publicKeyPem: string;
  receipt: Buffer;
  environment: AttestEnv;
}

/**
 * Verifica una attestation de App Attest siguiendo
 * https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server
 * @param challenge el nonce emitido por el servidor (texto). El cliente usa clientDataHash = SHA256(challenge).
 */
export function verifyAttestation(opts: {
  keyId: string;
  attestationB64: string;
  challenge: string;
  app: AppIdentity;
  now?: Date;
  rootPem?: string;
}): AttestationResult {
  const obj = decodeCbor(Buffer.from(opts.attestationB64, "base64"));
  if (mapGet(obj, "fmt") !== "apple-appattest") throw new Error("bad fmt");
  const attStmt = mapGet(obj, "attStmt");
  const x5c = mapGet(attStmt, "x5c");
  const authDataRaw = mapGet(obj, "authData");
  if (!Array.isArray(x5c) || x5c.length < 2 || !(authDataRaw instanceof Uint8Array)) throw new Error("bad attStmt");

  const leaf = new X509Certificate(Buffer.from(x5c[0] as Uint8Array));
  const intermediate = new X509Certificate(Buffer.from(x5c[1] as Uint8Array));
  const root = new X509Certificate(opts.rootPem ?? APPLE_APP_ATTEST_ROOT_CA);
  const now = opts.now ?? new Date();
  for (const c of [leaf, intermediate]) {
    if (new Date(c.validFrom) > now || new Date(c.validTo) < now) throw new Error("certificate expired");
  }
  if (!leaf.verify(intermediate.publicKey) || !leaf.checkIssued(intermediate)) throw new Error("leaf not issued by intermediate");
  if (!intermediate.verify(root.publicKey) || !intermediate.checkIssued(root)) throw new Error("intermediate not issued by Apple root");

  const clientDataHash = sha256(Buffer.from(opts.challenge, "utf8"));
  const expectedNonce = sha256(authDataRaw, clientDataHash);
  if (!extractNonce(leaf.raw).equals(expectedNonce)) throw new Error("nonce mismatch");

  const point = uncompressedPoint(leaf.publicKey);
  const keyIdBytes = Buffer.from(opts.keyId, "base64");
  if (!sha256(point).equals(keyIdBytes)) throw new Error("keyId mismatch");

  const auth = parseAuthData(authDataRaw);
  if (!auth.rpIdHash.equals(sha256(Buffer.from(`${opts.app.teamId}.${opts.app.bundleId}`)))) throw new Error("rpIdHash mismatch");
  if (auth.counter !== 0) throw new Error("counter must be 0");
  let environment: AttestEnv;
  if (auth.aaguid?.equals(AAGUID_PROD)) environment = "production";
  else if (auth.aaguid?.equals(AAGUID_DEV)) environment = "development";
  else throw new Error("bad aaguid");
  if (environment !== opts.app.env && !(environment === "development" && opts.app.allowDevelopment)) {
    throw new Error("wrong App Attest environment");
  }
  if (!auth.credentialId?.equals(keyIdBytes)) throw new Error("credentialId mismatch");

  const receipt = mapGet(attStmt, "receipt");
  return {
    publicKeyPem: leaf.publicKey.export({ type: "spki", format: "pem" }) as string,
    receipt: receipt instanceof Uint8Array ? Buffer.from(receipt) : Buffer.alloc(0),
    environment,
  };
}

/** Verifica una assertion. Devuelve el nuevo contador (debe guardarse). */
export function verifyAssertion(opts: {
  assertionB64: string;
  challenge: string;
  publicKeyPem: string;
  previousCounter: number;
  app: AppIdentity;
}): number {
  const obj = decodeCbor(Buffer.from(opts.assertionB64, "base64"));
  const signature = mapGet(obj, "signature");
  const authData = mapGet(obj, "authenticatorData");
  if (!(signature instanceof Uint8Array) || !(authData instanceof Uint8Array)) throw new Error("bad assertion");
  const clientDataHash = sha256(Buffer.from(opts.challenge, "utf8"));
  const nonce = sha256(authData, clientDataHash);
  const key = createPublicKey(opts.publicKeyPem);
  if (!cryptoVerify("sha256", nonce, key, Buffer.from(signature))) throw new Error("bad signature");
  const auth = parseAuthData(authData);
  if (!auth.rpIdHash.equals(sha256(Buffer.from(`${opts.app.teamId}.${opts.app.bundleId}`)))) throw new Error("rpIdHash mismatch");
  if (auth.counter <= opts.previousCounter) throw new Error("counter replay");
  return auth.counter;
}
