"use client";

import { startRegistration, startAuthentication } from "@simplewebauthn/browser";
import { fetchJson } from "@/lib/fetchJson";

/**
 * WebAuthn (Passkey) requires a *user gesture*.
 * Many browsers do NOT allow calling startRegistration/startAuthentication after awaiting network.
 *
 * Strategy:
 * - Prefetch "start" options ahead of time (on page load / focus), store in memory.
 * - On button click, call startRegistration/startAuthentication immediately using cached options.
 * - If options are missing/expired, tell the UI to retry (it will prefetch again).
 */

let regOptionsCache: any | null = null;
let loginOptionsCache: any | null = null;

export async function preparePasskeyRegisterOptions() {
  regOptionsCache = await fetchJson<any>("/api/auth/passkey/register/start", {
    method: "GET",
    cache: "no-store",
  });
  return true;
}

export async function preparePasskeyLoginOptions() {
  loginOptionsCache = await fetchJson<any>("/api/auth/passkey/login/start", {
    method: "GET",
    cache: "no-store",
  });
  return true;
}

export async function passkeyRegister() {
  if (!regOptionsCache) {
    // No cached options => likely first load or expired. Ask UI to retry after prefetch.
    throw new Error("Passkey準備中です。もう一度ボタンを押してください。");
  }

  const attResp = await startRegistration(regOptionsCache);

  const finish = await fetchJson<{ ok: boolean; error?: string }>("/api/auth/passkey/register/finish", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(attResp),
  });

  // Clear cache after use (challenge is single-use)
  regOptionsCache = null;

  if (!finish.ok) throw new Error(finish.error ?? "register failed");
  return true;
}

export async function passkeyLogin() {
  if (!loginOptionsCache) {
    throw new Error("Passkey準備中です。もう一度ボタンを押してください。");
  }

  const asseResp = await startAuthentication(loginOptionsCache);

  const finish = await fetchJson<{ ok: boolean; error?: string }>("/api/auth/passkey/login/finish", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(asseResp),
  });

  loginOptionsCache = null;

  if (!finish.ok) throw new Error(finish.error ?? "login failed");
  return true;
}

export async function logout() {
  await fetch("/api/auth/logout", { method: "POST" });
  // Clear caches so next attempt re-prefetches
  regOptionsCache = null;
  loginOptionsCache = null;
}
