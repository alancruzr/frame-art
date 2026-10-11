import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { authenticate, legacyEnabled } from "../lib/auth";
import { issueSession } from "../lib/session";

const LEGACY_KEY = "synthetic-legacy-key-for-tests";
const SESSION_SECRET = "synthetic-session-secret-long-enough-for-tests";
const ENV_KEYS = ["FRAME_STUDIO_PUBLISH_KEY", "FRAME_STUDIO_SESSION_SECRET", "FRAME_STUDIO_LEGACY_KEY_ENABLED"];
const originalEnv = new Map<string, string | undefined>();

beforeEach(() => {
  originalEnv.clear();
  for (const key of ENV_KEYS) {
    originalEnv.set(key, process.env[key]);
    delete process.env[key];
  }
});

afterEach(() => {
  for (const key of ENV_KEYS) {
    const original = originalEnv.get(key);
    if (original === undefined) delete process.env[key];
    else process.env[key] = original;
  }
});

function authorizedRequest(token: string): Request {
  return new Request("https://frame-studio.test/api/publish", {
    headers: { authorization: `Bearer ${token}` },
  });
}

describe("publish auth migration window", () => {
  it("keeps legacy clients working by default", () => {
    process.env.FRAME_STUDIO_PUBLISH_KEY = LEGACY_KEY;

    expect(legacyEnabled()).toBe(true);
    expect(authenticate(authorizedRequest(LEGACY_KEY))).toEqual({ kind: "legacy" });
  });

  it("accepts App Attest sessions alongside legacy clients", () => {
    process.env.FRAME_STUDIO_PUBLISH_KEY = LEGACY_KEY;
    process.env.FRAME_STUDIO_SESSION_SECRET = SESSION_SECRET;
    const token = issueSession({ keyId: "test-device", studio: "atelier" }, SESSION_SECRET);

    expect(authenticate(authorizedRequest(token))).toEqual({
      kind: "session",
      session: { keyId: "test-device", studio: "atelier" },
    });
  });

  it("rejects legacy clients only after an explicit server cutover", () => {
    process.env.FRAME_STUDIO_PUBLISH_KEY = LEGACY_KEY;
    process.env.FRAME_STUDIO_LEGACY_KEY_ENABLED = "false";

    const result = authenticate(authorizedRequest(LEGACY_KEY));
    expect(result).toBeInstanceOf(Response);
    expect((result as Response).status).toBe(401);
  });
});
