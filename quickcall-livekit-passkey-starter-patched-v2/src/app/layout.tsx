import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "QuickCall",
  description: "Cloud-managed video call MVP with passkey host login",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
