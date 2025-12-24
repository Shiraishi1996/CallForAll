"use client";

import React, { useEffect, useMemo, useState } from "react";
import "@livekit/components-styles";
import {
  LiveKitRoom,
  VideoConference,
  RoomAudioRenderer,
  ConnectionStateToast,
  useRoomContext,
} from "@livekit/components-react";
import { RoomEvent, ConnectionState } from "livekit-client";

type Diag = { at: number; level: "info" | "warn" | "error"; msg: string };

function fmtTime(ts: number) {
  return new Date(ts).toLocaleTimeString();
}

function DiagnosticsPanel({
  initial,
}: {
  initial: Diag[];
}) {
  const room = useRoomContext();
  const [logs, setLogs] = useState<Diag[]>(initial ?? []);
  const [open, setOpen] = useState(true);

  const push = (level: Diag["level"], msg: string) => {
    setLogs((prev) => [...prev, { at: Date.now(), level, msg }]);
  };

  useEffect(() => {
    // Initial status
    push("info", `ConnectionState=${room.state}`);

    const onConn = (state: ConnectionState) => {
      push("info", `ConnectionStateChanged: ${state}`);
      if (state === ConnectionState.Disconnected) setOpen(true);
    };
    const onDisc = (reason?: any) => {
      // reason is numeric enum in some SDK versions
      push("error", `Disconnected: ${String(reason ?? "(no reason)")}`);
      setOpen(true);
    };
    const onReconn = () => push("warn", "Reconnecting...");
    const onReconned = () => push("info", "Reconnected");
    const onSig = () => push("info", "SignalConnected");
    const onSigClosed = () => push("warn", "SignalDisconnected");
    const onErr = (err: any) => {
      push("error", `RoomError: ${String(err?.message ?? err)}`);
      setOpen(true);
    };
    const onJoined = () => {
      push("info", `Joined room: ${room.name || "(unknown)"}`);
      push("info", `Local identity: ${room.localParticipant?.identity || "(unknown)"}`);
    };

    room.on(RoomEvent.ConnectionStateChanged, onConn);
    room.on(RoomEvent.Disconnected, onDisc);
    room.on(RoomEvent.Reconnecting, onReconn);
    room.on(RoomEvent.Reconnected, onReconned);
    room.on(RoomEvent.SignalConnected, onSig);
    // SignalDisconnected イベントは存在しないので、Disconnectedイベントで代用
    room.on(RoomEvent.RoomMetadataChanged, onJoined);
    room.on(RoomEvent.ParticipantConnected, (p) => push("info", `ParticipantConnected: ${p.identity}`));
    room.on(RoomEvent.ParticipantDisconnected, (p) => push("warn", `ParticipantDisconnected: ${p.identity}`));
    room.on(RoomEvent.TrackSubscriptionFailed, (sid, err) => push("warn", `TrackSubscriptionFailed: ${sid} ${String(err)}`));
    room.on(RoomEvent.TrackSubscribed, (_t, pub, p) => push("info", `TrackSubscribed: ${p.identity} ${pub.source}`));

    // after connect, name/identity are available
    setTimeout(() => onJoined(), 200);

    return () => {
      room.off(RoomEvent.ConnectionStateChanged, onConn);
      room.off(RoomEvent.Disconnected, onDisc);
      room.off(RoomEvent.Reconnecting, onReconn);
      room.off(RoomEvent.Reconnected, onReconned);
      room.off(RoomEvent.SignalConnected, onSig);
      room.off(RoomEvent.RoomMetadataChanged, onJoined);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div
      style={{
        position: "fixed",
        right: 12,
        bottom: 12,
        width: 420,
        maxWidth: "calc(100vw - 24px)",
        background: "#0b0b0b",
        color: "white",
        borderRadius: 14,
        padding: 10,
        boxShadow: "0 12px 30px rgba(0,0,0,0.35)",
        fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
        zIndex: 50,
      }}
    >
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8 }}>
        <div style={{ fontWeight: 900 }}>Connection diagnostics</div>
        <div style={{ display: "flex", gap: 8 }}>
          <button
            onClick={() => setOpen((v) => !v)}
            style={{
              background: "transparent",
              color: "white",
              border: "1px solid #333",
              borderRadius: 10,
              padding: "6px 10px",
              cursor: "pointer",
              fontWeight: 800,
            }}
          >
            {open ? "Hide" : "Show"}
          </button>
          <button
            onClick={() => setLogs([])}
            style={{
              background: "transparent",
              color: "white",
              border: "1px solid #333",
              borderRadius: 10,
              padding: "6px 10px",
              cursor: "pointer",
              fontWeight: 800,
            }}
          >
            Clear
          </button>
        </div>
      </div>

      <div style={{ marginTop: 6, fontSize: 12, opacity: 0.9 }}>
        Local: <b>{room.localParticipant?.identity || "(unknown)"}</b>
        <span style={{ marginLeft: 8 }}>
          Room: <b>{room.name || "(unknown)"}</b>
        </span>
        <span style={{ marginLeft: 8 }}>
          State: <b>{room.state}</b>
        </span>
      </div>

      {open && (
        <>
          <div style={{ marginTop: 8, fontSize: 12, opacity: 0.9 }}>
            Tips:
            <div style={{ opacity: 0.8, marginTop: 2 }}>
              ・Token API の status/body がNGだと joinできずに disconnect します（前画面のログ参照）
              <br />
              ・DevTools → Network → WS の close code で確定原因が分かります
              <br />
              ・同名入室で切れる場合は identity 重複が原因（この版は重複回避済み）
            </div>
          </div>

          <div
            style={{
              marginTop: 8,
              border: "1px solid #222",
              borderRadius: 12,
              padding: 8,
              maxHeight: 260,
              overflow: "auto",
              fontSize: 12,
              lineHeight: 1.5,
            }}
          >
            {logs.length === 0 ? (
              <div style={{ opacity: 0.7 }}>No logs yet.</div>
            ) : (
              logs.map((l, i) => (
                <div key={i} style={{ opacity: l.level === "info" ? 0.95 : 1 }}>
                  [{fmtTime(l.at)}] {l.level.toUpperCase()}: {l.msg}
                </div>
              ))
            )}
          </div>
        </>
      )}
    </div>
  );
}

function ChatPanel() {
  const room = useRoomContext();
  const [messages, setMessages] = useState<
    { id: string; name: string; text: string; at: number; mine: boolean }[]
  >([]);
  const [text, setText] = useState("");

  useEffect(() => {
    const onData = (payload: Uint8Array, participant?: any) => {
      try {
        const t = new TextDecoder().decode(payload);
        const obj = JSON.parse(t);
        if (!obj?.id) return;
        setMessages((prev) => [
          ...prev,
          {
            id: obj.id,
            name: obj.name || participant?.name || participant?.identity || "unknown",
            text: obj.text || "",
            at: obj.at || Date.now(),
            mine: false,
          },
        ]);
      } catch {
        // ignore
      }
    };

    room.on(RoomEvent.DataReceived, onData);
    return () => {
      room.off(RoomEvent.DataReceived, onData);
    };
  }, [room]);

  const send = async () => {
    const t = text.trim();
    if (!t) return;
    const msg = {
      id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
      name: room.localParticipant?.name || room.localParticipant?.identity || "me",
      text: t,
      at: Date.now(),
    };

    try {
      room.localParticipant.publishData(
        new TextEncoder().encode(JSON.stringify(msg)),
        { reliable: true }
      );
      setMessages((prev) => [
        ...prev,
        { id: msg.id, name: msg.name, text: msg.text, at: msg.at, mine: true },
      ]);
      setText("");
    } catch {
      // ignore
    }
  };

  return (
    <div
      style={{
        position: "fixed",
        left: 12,
        bottom: 12,
        width: 360,
        maxWidth: "calc(100vw - 24px)",
        background: "rgba(0,0,0,0.85)",
        color: "white",
        borderRadius: 14,
        padding: 10,
        zIndex: 50,
        fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, sans-serif",
      }}
    >
      <div style={{ fontWeight: 900, marginBottom: 6 }}>Chat</div>
      <div style={{ maxHeight: 220, overflow: "auto", fontSize: 13, lineHeight: 1.35 }}>
        {messages.length === 0 ? (
          <div style={{ opacity: 0.75 }}>No messages yet.</div>
        ) : (
          messages.map((m) => (
            <div key={m.id} style={{ marginBottom: 8, opacity: m.mine ? 1 : 0.95 }}>
              <div style={{ fontSize: 11, opacity: 0.75 }}>
                {m.mine ? "You" : m.name} · {new Date(m.at).toLocaleTimeString()}
              </div>
              <div style={{ whiteSpace: "pre-wrap" }}>{m.text}</div>
            </div>
          ))
        )}
      </div>
      <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") send();
          }}
          placeholder="Type a message..."
          style={{
            flex: 1,
            padding: "8px 10px",
            borderRadius: 10,
            border: "1px solid #333",
            background: "#111",
            color: "white",
            outline: "none",
          }}
        />
        <button
          onClick={send}
          style={{
            padding: "8px 12px",
            borderRadius: 10,
            border: "none",
            background: "#fff",
            color: "#111",
            fontWeight: 900,
            cursor: "pointer",
          }}
        >
          Send
        </button>
      </div>
    </div>
  );
}

export default function CallRoom({
  roomId,
  token,
  serverUrl,
  preJoinDiagnostics,
}: {
  roomId: string;
  token: string;
  serverUrl: string;
  preJoinDiagnostics: Diag[];
}) {
  const connect = useMemo(() => {
    // The component handles connection; token/serverUrl must be correct.
    return true;
  }, []);

  return (
    <LiveKitRoom token={token} serverUrl={serverUrl} connect={connect} style={{ height: "100vh" }}>
      <ConnectionStateToast />
      <VideoConference />
      <ChatPanel />
      <DiagnosticsPanel initial={preJoinDiagnostics} />
      <RoomAudioRenderer />
    </LiveKitRoom>
  );
}
