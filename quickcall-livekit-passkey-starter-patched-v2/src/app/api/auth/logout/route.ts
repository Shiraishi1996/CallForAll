import { NextResponse } from "next/server";
import { clearSession } from "@/lib/session";

export const runtime = "nodejs";

export async function POST() {
  try {
    await clearSession();
    return NextResponse.json({ ok: true }, { status: 200 });
  } catch (e) {
    console.error("/api/auth/logout failed:", e);
    return NextResponse.json({ ok: false, error: "LOGOUT_FAILED" }, { status: 500 });
  }
}
