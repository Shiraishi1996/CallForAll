"use client";

import React, { useMemo, useState } from "react";
import CallRoom from "./CallRoom";

type Diag = { at: number; level: "info" | "warn" | "error"; msg: string };

function now() {
  return new Date().toLocaleTimeString();
}

function safeJsonParse(text: string): any | null {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function decodeJwtPayload(token: string): any | null {
  try {
    const parts = token.split(".");
    if (parts.length < 2) return null;
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const pad = b64.length % 4 ? "=".repeat(4 - (b64.length % 4)) : "";
    const json = atob(b64 + pad);
    return JSON.parse(json);
  } catch {
    return null;
  }
}

export default function RoomClient({ roomId }: { roomId: string }) {
  const roomIdSafe = useMemo(() => (roomId ?? "").trim(), [roomId]);

  const serverUrl =
    (process.env.NEXT_PUBLIC_LIVEKIT_URL ?? "").trim() ||
    (process.env.NEXT_PUBLIC_LIVEKIT_WS_URL ?? "").trim(); // fallback if user renamed

  const [displayName, setDisplayName] = useState<string>("");
  const [token, setToken] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [diag, setDiag] = useState<Diag[]>([]);
  const [tokenPayload, setTokenPayload] = useState<any | null>(null);

  const push = (level: Diag["level"], msg: string) => {
    setDiag((prev) => [...prev, { at: Date.now(), level, msg }]);
  };

  const urlOk = useMemo(() => {
    if (!serverUrl) return false;
    if (!serverUrl.startsWith("wss://") && !serverUrl.startsWith("ws://")) return false;
    return true;
  }, [serverUrl]);

  async function join() {
    setError(null);
    setToken(null);
    setTokenPayload(null);

    const name = displayName.trim();
    if (!roomIdSafe) {
      setError("roomId が空です（URLを確認してください）");
      return;
    }
    if (!name) {
      setError("表示名を入力してください");
      return;
    }
    if (!serverUrl) {
      setError(
        "NEXT_PUBLIC_LIVEKIT_URL が未設定です。.env に NEXT_PUBLIC_LIVEKIT_URL=\"wss://...\" を入れて dev サーバを再起動してください。"
      );
      return;
    }
    if (!urlOk) {
      setError(
        `NEXT_PUBLIC_LIVEKIT_URL が不正です: ${serverUrl}\n(wss:// で始まるURLを設定してください)`
      );
      return;
    }

    setBusy(true);
    push("info", `[${now()}] Joining started`);
    push("info", `[${now()}] serverUrl=${serverUrl}`);
    push("info", `[${now()}] roomId=${roomIdSafe}, name=${name}`);

    try {
      const qs = new URLSearchParams({ roomId: roomIdSafe, name }).toString();
      const url = `/api/livekit/token?${qs}`;

      // Use fetch() to always capture status/body (even when not JSON).
      const res = await fetch(url, { method: "GET", cache: "no-store" });
      const text = await res.text();

      push("info", `[${now()}] Token API status=${res.status}`);
      push("info", `[${now()}] Token API body=${text.slice(0, 500)}`);

      if (!res.ok) {
        setError(`Token API failed: HTTP ${res.status}\n${text}`);
        push("error", `[${now()}] Token API failed`);
        return; // IMPORTANT: do not connect
      }

      const json = safeJsonParse(text);
      if (!json || !json.ok || !json.token) {
        setError(`Token API returned invalid JSON.\n${text}`);
        push("error", `[${now()}] Token JSON invalid`);
        return; // do not connect
      }

      const payload = decodeJwtPayload(json.token);
      setTokenPayload(payload);
      push("info", `[${now()}] Token received (len=${String(json.token).length})`);
      if (payload) {
        const id = payload.sub ?? "";
        const room = payload.video?.room ?? payload.room ?? payload.video?.roomName ?? "";
        push("info", `[${now()}] Token payload: sub(identity)=${id}`);
        push("info", `[${now()}] Token payload: room=${room}`);
      } else {
        push("warn", `[${now()}] Token payload decode failed (still ok to try connect)`);
      }

      setToken(json.token);
    } catch (e: any) {
      const msg = String(e?.message ?? e);
      setError(msg);
      push("error", `[${now()}] Exception: ${msg}`);
    } finally {
      setBusy(false);
    }
  }

  if (token) {
    return (
      <CallRoom
        roomId={roomIdSafe}
        token={token}
        serverUrl={serverUrl}
        preJoinDiagnostics={diag}
      />
    );
  }

  return (
    <div style={{ maxWidth: 720, margin: "24px auto", padding: 16 }}>
      <h1 style={{ fontSize: 22, fontWeight: 800, marginBottom: 8 }}>
        QuickCall (Guest-only)
      </h1>

      <div style={{ fontSize: 13, opacity: 0.85, marginBottom: 12 }}>
        Room: <span style={{ fontFamily: "monospace" }}>{roomIdSafe || "(empty)"}</span>
      </div>

      <div
        style={{
          background: "#f7f7f7",
          border: "1px solid #e5e5e5",
          borderRadius: 12,
          padding: 12,
          marginBottom: 12,
        }}
      >
        <div style={{ fontSize: 12, marginBottom: 6, opacity: 0.85 }}>
          LiveKit URL（.env / NEXT_PUBLIC_LIVEKIT_URL）
        </div>
        <div style={{ fontFamily: "monospace", fontSize: 13, wordBreak: "break-all" }}>
          {serverUrl || "(not set)"}
        </div>
        {!serverUrl && (
          <div style={{ marginTop: 8, color: "#8a1f1f", fontSize: 12 }}>
            .env に NEXT_PUBLIC_LIVEKIT_URL=&quot;wss://....livekit.cloud&quot; を追加し、devサーバを再起動してください。
          </div>
        )}
        {serverUrl && !urlOk && (
          <div style={{ marginTop: 8, color: "#8a1f1f", fontSize: 12 }}>
            URL 形式が不正です（wss:// で始まる必要があります）
          </div>
        )}
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr", gap: 10, marginBottom: 12 }}>
        <div>
          <label style={{ display: "block", fontSize: 13, marginBottom: 6 }}>表示名</label>
          <input
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            placeholder="例：Haru"
            style={{
              width: "100%",
              padding: "10px 12px",
              borderRadius: 10,
              border: "1px solid #ccc",
              outline: "none",
            }}
          />
        </div>
      </div>

      {error && (
        <div
          style={{
            background: "#fff2f2",
            border: "1px solid #ffbdbd",
            color: "#8a1f1f",
            padding: 12,
            borderRadius: 12,
            marginBottom: 12,
            whiteSpace: "pre-wrap",
            fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
            fontSize: 12,
          }}
        >
          {error}
        </div>
      )}

      <button
        type="button"
        onClick={join}
        disabled={busy}
        style={{
          width: "100%",
          padding: "12px 14px",
          borderRadius: 12,
          border: "none",
          background: "#111",
          color: "white",
          fontWeight: 800,
          cursor: busy ? "not-allowed" : "pointer",
          opacity: busy ? 0.7 : 1,
          marginBottom: 10,
        }}
      >
        {busy ? "入室準備中..." : "入室する"}
      </button>

      {tokenPayload && (
        <details style={{ marginTop: 8, marginBottom: 12 }}>
          <summary style={{ cursor: "pointer", fontWeight: 700 }}>Token payload（デバッグ）</summary>
          <pre style={{ fontSize: 12, overflow: "auto", background: "#0b0b0b", color: "#fff", padding: 12, borderRadius: 12 }}>
{JSON.stringify(tokenPayload, null, 2)}
          </pre>
        </details>
      )}

      <details open style={{ marginTop: 6 }}>
        <summary style={{ cursor: "pointer", fontWeight: 800 }}>Pre-join diagnostics</summary>
        <div
          style={{
            marginTop: 8,
            background: "#0b0b0b",
            color: "white",
            borderRadius: 12,
            padding: 10,
            fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
            fontSize: 12,
            maxHeight: 240,
            overflow: "auto",
          }}
        >
          {diag.length === 0 ? (
            <div style={{ opacity: 0.8 }}>No logs yet.</div>
          ) : (
            diag.map((d, i) => (
              <div key={i} style={{ opacity: d.level === "info" ? 0.95 : 1 }}>
                [{new Date(d.at).toLocaleTimeString()}] {d.level.toUpperCase()}: {d.msg}
              </div>
            ))
          )}
        </div>
      </details>

      <div style={{ marginTop: 12, fontSize: 12, opacity: 0.8 }}>
        もし「Disconnected」になる場合：まず Token API の status/body をここで確認してください。
        <br />
        それでも不明なら DevTools → Network → WS の close code を見ると確定します。
      </div>
    </div>
  );
}
