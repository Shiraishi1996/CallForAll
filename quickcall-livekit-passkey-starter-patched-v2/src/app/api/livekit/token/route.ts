import { NextResponse } from "next/server";
import { AccessToken } from "livekit-server-sdk";

export const runtime = "nodejs";

/**
 * Guest-only token endpoint (no login required).
 * GET /api/livekit/token?roomId=...&name=...
 */
export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const roomId = (searchParams.get("roomId") ?? "").trim();
    const name = (searchParams.get("name") ?? "").trim();

    if (!roomId || !name) {
      return NextResponse.json(
        { ok: false, error: "missing roomId or name" },
        { status: 400 }
      );
    }

    const apiKey = (process.env.LIVEKIT_API_KEY ?? "").trim();
    const apiSecret = (process.env.LIVEKIT_API_SECRET ?? "").trim();
    if (!apiKey || !apiSecret) {
      return NextResponse.json(
        {
          ok: false,
          error:
            "LIVEKIT_API_KEY / LIVEKIT_API_SECRET is not set. Please set them in .env and restart the dev server.",
        },
        { status: 500 }
      );
    }

    // Make identity unique to avoid kick/disconnect when the same name joins twice.
    const rid = Math.random().toString(36).slice(2, 10 );
    const identity = `guest:${name}:${rid}`;

    // Token TTL: 2 hours (avoid unexpected expiration during testing)
    const at = new AccessToken(apiKey, apiSecret, {
      identity,
      name, // display name (shown in UI)
      ttl: 60 * 60 * 2,
    });

    at.addGrant({
      room: roomId,
      roomJoin: true,
      canSubscribe: true,
      canPublish: true,
      canPublishData: true, // chat via data channel
    });

    // livekit-server-sdk v2+ returns a Promise here; if you don't await, JSON becomes {}.
    const token = await at.toJwt();

    if (typeof token !== "string" || token.length < 50) {
      return NextResponse.json(
        {
          ok: false,
          error:
            "Token generation failed (unexpected token type/length). Check LIVEKIT_API_KEY/SECRET and server time.",
          debug: {
            tokenType: typeof token,
            tokenLength: typeof token === "string" ? token.length : null,
          },
        },
        { status: 500 }
      );
    }

    return NextResponse.json({ ok: true, token, identity, roomId }, { status: 200 });
  } catch (e: any) {
    console.error("livekit/token failed:", e);
    return NextResponse.json({ ok: false, error: String(e?.message ?? e) }, { status: 500 });
  }
}

export async function POST() {
  return NextResponse.json({ ok: false, error: "Use GET" }, { status: 405 });
}
