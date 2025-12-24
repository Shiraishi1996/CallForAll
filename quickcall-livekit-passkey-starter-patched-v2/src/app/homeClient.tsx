"use client";

import React from "react";
import { Card, Button } from "./components/ui";

function randomRoomId() {
  const s = crypto.getRandomValues(new Uint8Array(12));
  return Array.from(s)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export default function HomeClient() {
  const [name, setName] = React.useState("");
  const [roomId, setRoomId] = React.useState("");

  function go(room: string) {
    const n = name.trim() || "guest";
    const qs = new URLSearchParams({ name: n }).toString();
    window.location.href = `/r/${room}?${qs}`;
  }

  return (
    <div style={{ maxWidth: 720, margin: "40px auto", padding: 16 }}>
      <h1 style={{ fontSize: 28, fontWeight: 800, marginBottom: 8 }}>QuickCall</h1>
      <div style={{ opacity: 0.75, marginBottom: 18 }}>
        ログイン不要。表示名だけで通話に参加できます（ミュート / ビデオ / 画面共有 / チャット対応）。
      </div>

      <Card>
        <div style={{ display: "grid", gap: 12 }}>
          <div>
            <div style={{ fontSize: 13, marginBottom: 6 }}>表示名</div>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="例：Haru"
              style={{
                width: "100%",
                padding: "10px 12px",
                borderRadius: 10,
                border: "1px solid rgba(0,0,0,0.2)",
                outline: "none",
              }}
            />
          </div>

          <div style={{ display: "flex", gap: 10 }}>
            <Button
              onClick={() => {
                const rid = randomRoomId();
                go(rid);
              }}
            >
              新しい通話を作成
            </Button>
          </div>

          <div>
            <div style={{ fontSize: 13, marginBottom: 6 }}>既存ルームに参加</div>
            <div style={{ display: "flex", gap: 10 }}>
              <input
                value={roomId}
                onChange={(e) => setRoomId(e.target.value)}
                placeholder="roomId を入力"
                style={{
                  flex: 1,
                  padding: "10px 12px",
                  borderRadius: 10,
                  border: "1px solid rgba(0,0,0,0.2)",
                  outline: "none",
                }}
              />
              <Button
                onClick={() => {
                  const rid = roomId.trim();
                  if (!rid) return;
                  go(rid);
                }}
              >
                参加
              </Button>
            </div>
          </div>
        </div>
      </Card>

      <div style={{ marginTop: 18, fontSize: 13, opacity: 0.7, lineHeight: 1.6 }}>
        <div>必要な env：</div>
        <div style={{ fontFamily: "monospace" }}>
          NEXT_PUBLIC_LIVEKIT_URL / LIVEKIT_API_KEY / LIVEKIT_API_SECRET
        </div>
      </div>
    </div>
  );
}
