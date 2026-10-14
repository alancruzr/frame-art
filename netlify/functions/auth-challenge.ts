import type { Config, Context } from "@netlify/functions";
import { randomBytes } from "node:crypto";
import { challengesStore } from "../lib/devices";
import { allow, RATE, tooMany } from "../lib/limits";

export default async (req: Request, context: Context) => {
  if (req.method !== "GET" && req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  if (!(await allow(`challenge-ip:${context.ip}`, RATE.authPerIpHour * 3))) return tooMany();
  const nonce = randomBytes(32).toString("base64url");
  await challengesStore().set(nonce, String(Date.now()));
  return Response.json({ nonce }, { headers: { "Cache-Control": "no-store" } });
};

export const config: Config = { path: "/api/auth/challenge", method: ["GET", "POST"] };
