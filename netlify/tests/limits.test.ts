import { describe, expect, it } from "vitest";
import { MAX_BYTES, checkContentLength, validateBody } from "../lib/limits";

const buf = (bytes: number[], pad = 0) => new Uint8Array([...bytes, ...new Array(pad).fill(0)]).buffer;

describe("validateBody", () => {
  it("accepts real file signatures", () => {
    expect(validateBody("usdz", buf([0x50, 0x4b, 0x03, 0x04], 10))).toBeNull();
    expect(validateBody("glb", buf([0x67, 0x6c, 0x54, 0x46], 10))).toBeNull();
    expect(validateBody("poster", buf([0xff, 0xd8, 0xff], 10))).toBeNull();
    expect(validateBody("meta", buf([0x7b, 0x7d]))).toBeNull();
  });
  it("rejects spoofed types", () => {
    expect(validateBody("usdz", buf([0x67, 0x6c, 0x54, 0x46], 10))).toBe("invalid_usdz");
    expect(validateBody("glb", buf([0x50, 0x4b, 0x03, 0x04], 10))).toBe("invalid_glb");
    expect(validateBody("poster", buf([0x89, 0x50, 0x4e, 0x47]))).toBe("invalid_jpeg");
    expect(validateBody("exe", buf([1]))).toBe("invalid_kind");
  });
  it("enforces size limits", () => {
    expect(validateBody("meta", new ArrayBuffer(MAX_BYTES.meta + 1))).toBe("payload_too_large");
    expect(validateBody("poster", new ArrayBuffer(MAX_BYTES.poster + 1))).toBe("payload_too_large");
  });
});

describe("checkContentLength", () => {
  it("returns 413 early", async () => {
    const r = checkContentLength(new Request("https://x/api/publish", { method: "POST", headers: { "content-length": "999999999" } }), 10);
    expect(r?.status).toBe(413);
    expect(checkContentLength(new Request("https://x", { method: "POST", headers: { "content-length": "5" } }), 10)).toBeNull();
  });
});

import { isStudioSlug } from "../lib/store";
describe("isStudioSlug", () => {
  it("reserves site paths", () => {
    expect(isStudioSlug("taller-ana")).toBe(true);
    expect(isStudioSlug("privacy")).toBe(false);
    expect(isStudioSlug("api")).toBe(false);
    expect(isStudioSlug("Bad Slug")).toBe(false);
  });
});
