import { SignJWT, jwtVerify } from "jose";
import { cookies } from "next/headers";

const SESSION_COOKIE = "qc_session";
const REG_COOKIE = "qc_pk_reg";
const LOGIN_COOKIE = "qc_pk_login";

function secretKey(): Uint8Array {
  const s = process.env.SESSION_SECRET;
  if (!s) throw new Error("SESSION_SECRET is not set");
  return new TextEncoder().encode(s);
}

export async function setSession(userId: string) {
  const token = await new SignJWT({ userId })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("14d")
    .sign(secretKey());

  cookies().set(SESSION_COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
  });
}

export async function clearSession() {
  cookies().set(SESSION_COOKIE, "", { path: "/", maxAge: 0 });
}

export async function getSessionUserId(): Promise<string | null> {
  const token = cookies().get(SESSION_COOKIE)?.value;
  if (!token) return null;
  try {
    const { payload } = await jwtVerify(token, secretKey());
    const userId = payload.userId;
    return typeof userId === "string" ? userId : null;
  } catch {
    return null;
  }
}

export type PendingPasskey = { userId?: string; challenge: string };

async function setTempCookie(name: string, data: object, expiresIn: string) {
  const token = await new SignJWT(data)
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime(expiresIn)
    .sign(secretKey());

  cookies().set(name, token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
  });
}

async function readTempCookie<T>(name: string): Promise<T | null> {
  const token = cookies().get(name)?.value;
  if (!token) return null;
  try {
    const { payload } = await jwtVerify(token, secretKey());
    return payload as unknown as T;
  } catch {
    return null;
  }
}

export async function setPasskeyRegState(userId: string, challenge: string) {
  await setTempCookie(REG_COOKIE, { userId, challenge }, "10m");
}

export async function readPasskeyRegState(): Promise<PendingPasskey | null> {
  return await readTempCookie<PendingPasskey>(REG_COOKIE);
}

export async function clearPasskeyRegState() {
  cookies().set(REG_COOKIE, "", { path: "/", maxAge: 0 });
}

export async function setPasskeyLoginState(challenge: string) {
  await setTempCookie(LOGIN_COOKIE, { challenge }, "10m");
}

export async function readPasskeyLoginState(): Promise<{ challenge: string } | null> {
  return await readTempCookie<{ challenge: string }>(LOGIN_COOKIE);
}

export async function clearPasskeyLoginState() {
  cookies().set(LOGIN_COOKIE, "", { path: "/", maxAge: 0 });
}
