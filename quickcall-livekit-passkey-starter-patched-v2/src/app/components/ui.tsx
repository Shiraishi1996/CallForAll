"use client";

import React from "react";

export function Card(props: React.PropsWithChildren<{ title?: string }>) {
  return (
    <div style={{
      border: "1px solid rgba(255,255,255,0.12)",
      borderRadius: 18,
      padding: 18,
      background: "rgba(255,255,255,0.04)",
      boxShadow: "0 10px 30px rgba(0,0,0,0.25)"
    }}>
      {props.title ? <div style={{ fontSize: 18, fontWeight: 700, marginBottom: 10 }}>{props.title}</div> : null}
      {props.children}
    </div>
  );
}

export function Button(props: React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: "primary" | "ghost" }) {
  const variant = props.variant ?? "primary";
  return (
    <button
      {...props}
      style={{
        padding: "10px 14px",
        borderRadius: 14,
        border: variant === "ghost" ? "1px solid rgba(255,255,255,0.18)" : "1px solid rgba(255,255,255,0.10)",
        background: variant === "ghost" ? "transparent" : "rgba(255,255,255,0.12)",
        color: "#fff",
        fontWeight: 700,
        ...props.style,
      }}
    />
  );
}

export function TextInput(props: React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      {...props}
      style={{
        width: "100%",
        padding: "10px 12px",
        borderRadius: 14,
        border: "1px solid rgba(255,255,255,0.18)",
        background: "rgba(0,0,0,0.35)",
        color: "#fff",
        outline: "none",
        ...props.style,
      }}
    />
  );
}
