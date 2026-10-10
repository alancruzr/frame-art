import { getStore } from "@netlify/blobs";
import type { AppIdentity, AttestEnv } from "./appattest";
import { envGet } from "./store";

export const challengesStore = () => getStore({ name: "challenges", consistency: "strong" });
export const devicesStore = () => getStore({ name: "devices", consistency: "strong" });
export const ownersStore = () => getStore({ name: "owners", consistency: "strong" });

export interface DeviceRecord { publicKeyPem: string; counter: number; environment: AttestEnv; createdAt: string }
export interface OwnerRecord { keyIds: string[]; createdAt: string; legacy?: boolean }

export const CHALLENGE_TTL_MS = 5 * 60_000;

export function appIdentity(): AppIdentity | null {
  const teamId = envGet("APPLE_TEAM_ID");
  const bundleId = envGet("APPLE_BUNDLE_ID") || "com.alancruzr.frameart";
  const env = (envGet("APP_ATTEST_ENV") || "production") as AttestEnv;
  if (!teamId) return null;
  return { teamId, bundleId, env, allowDevelopment: (envGet("APP_ATTEST_ALLOW_DEVELOPMENT") || "false") === "true" };
}

/** Consume un challenge (uso único). */
export async function consumeChallenge(nonce: string): Promise<boolean> {
  if (typeof nonce !== "string" || !/^[A-Za-z0-9_-]{32,64}$/.test(nonce)) return false;
  const store = challengesStore();
  const issued = await store.get(nonce, { type: "text" });
  if (!issued) return false;
  await store.delete(nonce);
  return Date.now() - Number(issued) <= CHALLENGE_TTL_MS;
}

/** Reclama el estudio para keyId o comprueba que ya le pertenece. */
export async function claimStudio(studio: string, keyId: string): Promise<"ok" | "taken"> {
  const store = ownersStore();
  const owner = (await store.get(studio, { type: "json" })) as OwnerRecord | null;
  if (!owner || (owner.legacy && owner.keyIds.length === 0)) {
    await store.setJSON(studio, { keyIds: [keyId], createdAt: owner?.createdAt ?? new Date().toISOString() });
    return "ok";
  }
  return owner.keyIds.includes(keyId) ? "ok" : "taken";
}
