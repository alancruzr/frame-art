import type { Config, Context } from "@netlify/functions";
import { verifyAttestation } from "../lib/appattest";
import { appIdentity, claimStudio, consumeChallenge, devicesStore, type DeviceRecord } from "../lib/devices";
import { allow, RATE, tooMany } from "../lib/limits";
import { issueSession } from "../lib/session";
import { envGet, isStudioSlug } from "../lib/store";

const json = (status: number, body: unknown) => Response.json(body, { status, headers: { "Cache-Control": "no-store" } });

export default async (req: Request, context: Context) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  const secret = envGet("FRAME_STUDIO_SESSION_SECRET") || "";
  const app = appIdentity();
  if (secret.length < 32 || !app) return json(503, { error: "app_attest_not_configured" });
  if (!(await allow(`attest-ip:${context.ip}`, RATE.authPerIpHour))) return tooMany();

  let body: { keyId?: string; attestation?: string; nonce?: string; studio?: string };
  try { body = await req.json(); } catch { return json(400, { error: "bad_json" }); }
  const { keyId, attestation, nonce, studio } = body;
  if (typeof keyId !== "string" || typeof attestation !== "string" || typeof studio !== "string" || !isStudioSlug(studio)) {
    return json(400, { error: "bad_request" });
  }
  if (attestation.length > 16_384) return json(413, { error: "payload_too_large" });
  if (!(await consumeChallenge(nonce ?? ""))) return json(401, { error: "stale_challenge" });

  let result;
  try {
    result = verifyAttestation({ keyId, attestationB64: attestation, challenge: nonce!, app });
  } catch (e) {
    console.warn("attest failed", (e as Error).message);
    return json(401, { error: "attestation_failed" });
  }

  const record: DeviceRecord = { publicKeyPem: result.publicKeyPem, counter: 0, environment: result.environment, createdAt: new Date().toISOString() };
  await devicesStore().setJSON(keyId.replace(/\//g, "_"), record);

  if ((await claimStudio(studio, keyId)) === "taken") return json(409, { error: "studio_taken" });
  return json(200, { token: issueSession({ keyId, studio }, secret) });
};

export const config: Config = { path: "/api/auth/attest", method: ["POST"] };
