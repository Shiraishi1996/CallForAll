import { NextResponse } from "next/server";
import { verifyAuthenticationResponse } from "@simplewebauthn/server";
import type { AuthenticationResponseJSON } from "@simplewebauthn/types";
import { prisma } from "@/lib/prisma";
import { readPasskeyLoginState, clearPasskeyLoginState, setSession } from "@/lib/session";

export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const body = (await req.json()) as AuthenticationResponseJSON;

    const state = await readPasskeyLoginState();
    if (!state?.challenge) {
      return NextResponse.json({ ok: false, error: "login state missing" }, { status: 400 });
    }

    const expectedOrigin = process.env.WEBAUTHN_ORIGIN ?? "http://localhost:3000";
    const expectedRPID = process.env.WEBAUTHN_RP_ID ?? "localhost";

    const credentialID = body.id; // base64url string
    const cred = await prisma.credential.findUnique({ where: { credentialID } });

    if (!cred) {
      return NextResponse.json({ ok: false, error: "credential not found" }, { status: 404 });
    }

    const verification = await verifyAuthenticationResponse({
      response: body,
      expectedChallenge: state.challenge,
      expectedOrigin,
      expectedRPID,
      authenticator: {
        credentialID: cred.credentialID,
        credentialPublicKey: Buffer.from(cred.credentialPublicKey, "base64"),
        counter: cred.counter,
        transports: cred.transports ? cred.transports.split(",").filter(Boolean) as any : [],
      } as any,
    });

    if (!verification.verified) {
      return NextResponse.json({ ok: false, error: "passkey verify failed" }, { status: 401 });
    }

    // Update counter to prevent replay
    await prisma.credential.update({
      where: { id: cred.id },
      data: { counter: verification.authenticationInfo.newCounter },
    });

    await clearPasskeyLoginState();
    await setSession(cred.userId);

    return NextResponse.json({ ok: true });
  } catch (e: any) {
    return NextResponse.json({ ok: false, error: e?.message ?? String(e) }, { status: 500 });
  }
}
