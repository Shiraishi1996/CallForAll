import { NextResponse } from "next/server";
import { generateAuthenticationOptions } from "@simplewebauthn/server";
import { setPasskeyLoginState } from "@/lib/session";

export const runtime = "nodejs";

export async function POST() {
  try {
    const rpID = process.env.WEBAUTHN_RP_ID ?? "localhost";

    const opts = await generateAuthenticationOptions({
      rpID,
      userVerification: "preferred",
    });

    await setPasskeyLoginState(opts.challenge);

    return NextResponse.json(opts, { status: 200 });
  } catch (e: any) {
    console.error("/api/auth/passkey/login/start failed:", e);
    return NextResponse.json({ ok: false, error: e?.message ?? String(e) }, { status: 500 });
  }
}
