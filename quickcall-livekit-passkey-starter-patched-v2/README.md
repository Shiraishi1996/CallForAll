# QuickCall (LiveKit Cloud + Passkey host login)

最短で「Zoom風オンライン通話」 + 「ログインが楽（主催者=パスキー1タップ / 参加者=ログイン不要）」を動かす雛形です。

## 1) 必要なもの
- LiveKit Cloud の Project（URL / API KEY / API SECRET）
- Node.js（LTS推奨）

## 2) セットアップ
```bash
npm i
cp .env.example .env
```

`.env` を編集して LiveKit Cloud と WebAuthn を設定します。

例（ローカル開発）:
- WEBAUTHN_RP_ID=localhost
- WEBAUTHN_ORIGIN=http://localhost:3000

DB初期化（SQLite）:
```bash
npx prisma migrate dev --name init
```

起動:
```bash
npm run dev
```

### Windows メモ（Dropbox配下は避ける）
Dropbox配下など、パスに `()` が入る場所（例: `Dropbox\PC (3)\...`）だと、
Next.js のエディタ連携や `.next\cache` でエラーになりやすいです。

おすすめ: `C:\dev\quickcall\` など括弧なしパスに配置してください。

## 3) 使い方
- トップで「パスキー登録（主催者）」→ 指紋/顔/Helloで登録
- 「新しい通話を作成」→ ルームへ（host=1）
- 参加者はURLを開いて表示名だけで入室

## 4) 本番デプロイ時の注意
- Passkey(WebAuthn) は基本的に HTTPS が必要（localhostだけ例外）
- WEBAUTHN_RP_ID と WEBAUTHN_ORIGIN を本番ドメインに合わせて変更
- SQLite のままは避け、Postgres等に切り替え（Prismaのprovider変更）

## 5) 次の差別化（おすすめ順）
- 待機室（主催者承認）
- ルームロック（新規参加停止）
- 参加レート制限 / 迷惑行為検知
- QRで別端末ログイン（PC→スマホ）
