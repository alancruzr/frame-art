import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { appIdentity } from "../lib/devices";

const ENV_KEYS = ["APPLE_TEAM_ID", "APPLE_BUNDLE_ID", "APP_ATTEST_ENV", "APP_ATTEST_ALLOW_DEVELOPMENT"];
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

describe("App Attest server identity", () => {
  it("uses production defaults and does not accept development attestations by default", () => {
    process.env.APPLE_TEAM_ID = "TESTTEAM01";

    expect(appIdentity()).toEqual({
      teamId: "TESTTEAM01",
      bundleId: "app.framestudio.ios",
      env: "production",
      allowDevelopment: false,
    });
  });

  it("requires an explicit opt-in before accepting development attestations", () => {
    process.env.APPLE_TEAM_ID = "TESTTEAM01";
    process.env.APP_ATTEST_ALLOW_DEVELOPMENT = "true";

    expect(appIdentity()?.allowDevelopment).toBe(true);
  });

  it("does not initialize App Attest without a Team ID", () => {
    expect(appIdentity()).toBeNull();
  });
});
