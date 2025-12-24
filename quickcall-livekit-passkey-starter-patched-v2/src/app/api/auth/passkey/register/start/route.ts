import { NextResponse } from "next/server";
import { generateRegistrationOptions } from "@simplewebauthn/server";
import { prisma } from "@/lib/prisma";
import { setPasskeyRegState } from "@/lib/session";

export const runtime = "nodejs";

export async function GET() {
  try {
    // 仮ユーザー（主催者）を作成 or 取得
    const user = await prisma.user.create({
      data: {
        name: "host",
      },
    });

    const options = await generateRegistrationOptions({
      rpName: "QuickCall",
      rpID: process.env.WEBAUTHN_RP_ID!,
      userID: Buffer.from(user.id, "utf8"), // ★ string → bytes
      userName: user.name ?? user.id,

      attestationType: "none",
      authenticatorSelection: {
        residentKey: "preferred",
        userVerification: "preferred",
      },
    });

    // challenge をセッションに保存
    await setPasskeyRegState({
      userId: user.id,
      challenge: options.challenge,
    });

    return NextResponse.json(options);
  } catch (e: any) {
    console.error("passkey register start failed:", e);
    return NextResponse.json(
      { ok: false, error: String(e?.message ?? e) },
      { status: 500 }
    );
  }
}


export async function POST() {
  return GET();
}
