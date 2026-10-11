import type { Config, Context } from "@netlify/functions";
import { verifyAssertion } from "../lib/appattest";
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
  if (!(await allow(`assert-ip:${context.ip}`, RATE.authPerIpHour * 3))) return tooMany();

  let body: { keyId?: string; assertion?: string; nonce?: string; studio?: string };
  try { body = await req.json(); } catch { return json(400, { error: "bad_json" }); }
  const { keyId, assertion, nonce, studio } = body;
  if (typeof keyId !== "string" || typeof assertion !== "string" || typeof studio !== "string" || !isStudioSlug(studio)) {
    return json(400, { error: "bad_request" });
  }
  if (assertion.length > 4096) return json(413, { error: "payload_too_large" });
  if (!(await consumeChallenge(nonce ?? ""))) return json(401, { error: "stale_challenge" });

  const devices = devicesStore();
  const deviceKey = keyId.replace(/\//g, "_");
  const device = (await devices.get(deviceKey, { type: "json" })) as DeviceRecord | null;
  if (!device) return json(401, { error: "unknown_key" }); // el cliente debe volver a atestiguar

  try {
    const counter = verifyAssertion({ assertionB64: assertion, challenge: nonce!, publicKeyPem: device.publicKeyPem, previousCounter: device.counter, app });
    await devices.setJSON(deviceKey, { ...device, counter });
  } catch (e) {
    console.warn("assert failed", (e as Error).message);
    return json(401, { error: "assertion_failed" });
  }

  if ((await claimStudio(studio, keyId)) === "taken") return json(409, { error: "studio_taken" });
  return json(200, { token: issueSession({ keyId, studio }, secret) });
};

export const config: Config = { path: "/api/auth/assert", method: ["POST"] };
