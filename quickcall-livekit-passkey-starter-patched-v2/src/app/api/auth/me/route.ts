import { NextResponse } from "next/server";
import { getSessionUserId } from "@/lib/session";

export const runtime = "nodejs";

export async function GET() {
  try {
    const userId = await getSessionUserId();
    return NextResponse.json({ userId: userId ?? null }, { status: 200 });
  } catch (e) {
    console.error("/api/auth/me failed:", e);
    // Always return JSON so the client never crashes on res.json().
    return NextResponse.json({ userId: null, error: "ME_FAILED" }, { status: 500 });
  }
}
