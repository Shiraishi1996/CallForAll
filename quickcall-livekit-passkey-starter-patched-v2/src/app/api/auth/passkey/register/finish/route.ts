import { NextResponse } from "next/server";
import { verifyRegistrationResponse } from "@simplewebauthn/server";
import { prisma } from "@/lib/prisma";
import { readPasskeyRegState, setSession, clearPasskeyRegState } from "@/lib/session";

export const runtime = "nodejs";

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const state = await readPasskeyRegState();
    if (!state) return NextResponse.json({ ok: false, error: "NO_REG_STATE" }, { status: 400 });

    const user = await prisma.user.findUnique({ where: { id: state.userId } });
    if (!user) return NextResponse.json({ ok: false, error: "USER_NOT_FOUND" }, { status: 404 });

    const verification = await verifyRegistrationResponse({
      response: body,
      expectedChallenge: state.challenge,
      expectedOrigin: process.env.WEBAUTHN_ORIGIN!,
      expectedRPID: process.env.WEBAUTHN_RP_ID!,
    });

    if (!verification.verified || !verification.registrationInfo) {
      return NextResponse.json({ ok: false, error: "REG_VERIFY_FAILED" }, { status: 400 });
    }

    const { credentialID, credentialPublicKey, counter } = verification.registrationInfo;

    await prisma.credential.create({
      data: {
        userId: user.id,
        credentialID: Buffer.from(credentialID).toString('base64'),
        credentialPublicKey: Buffer.from(credentialPublicKey).toString('base64'),
        counter,
      },
    });

    await setSession(user.id);
    await clearPasskeyRegState();
    return NextResponse.json({ ok: true });
  } catch (e: any) {
    console.error("register/finish failed:", e);
    return NextResponse.json({ ok: false, error: String(e?.message ?? e) }, { status: 500 });
  }
}

// デバッグ用：間違ってGETで叩いても405じゃなく理由が見えるように
export async function GET() {
  return NextResponse.json(
    { ok: false, error: "Use POST for /api/auth/passkey/register/finish" },
    { status: 405 }
  );
}
