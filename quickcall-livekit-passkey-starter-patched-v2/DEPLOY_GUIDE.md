# 🚀 デプロイガイド - 時間制限なしのホスティングサービス

## 📊 おすすめデプロイ先比較

| サービス | 無料枠 | 時間制限 | 特徴 | おすすめ度 |
|---------|--------|----------|------|-----------|
| **Render** | あり | **なし** | PostgreSQL無料、自動SSL | ⭐⭐⭐⭐⭐ |
| **Railway** | $5クレジット/月 | **なし** | 簡単デプロイ、DB付き | ⭐⭐⭐⭐ |
| **Fly.io** | あり | **なし** | 世界中にエッジサーバー | ⭐⭐⭐⭐ |
| **Vercel** | あり | **なし** | Next.js公式、高速 | ⭐⭐⭐⭐⭐ |
| **Netlify** | あり | **なし** | 静的サイト向き | ⭐⭐⭐ |
| **Cloudflare Pages** | あり | **なし** | 超高速CDN | ⭐⭐⭐⭐ |

## 🥇 最もおすすめ: Render.com

### なぜRenderがベストか
- ✅ **完全無料**（750時間/月 = 常時稼働可能）
- ✅ **PostgreSQL無料** (90日間、その後も無料延長可能)
- ✅ **自動HTTPS証明書**
- ✅ **カスタムドメイン対応**
- ✅ **自動デプロイ**（GitHubプッシュで更新）
- ✅ **環境変数GUI管理**
- ✅ **ログ表示**
- ✅ **時間制限なし**

## 📦 Renderへのデプロイ手順

### 1. Renderアカウント作成
[https://render.com](https://render.com) でアカウント作成（GitHubでログイン可能）

### 2. render.yamlファイルの作成
```yaml
services:
  - type: web
    name: quickcall-livekit
    runtime: node
    repo: https://github.com/Shiraishi1996/CallForAll
    branch: main
    rootDir: quickcall-livekit-passkey-starter-patched-v2
    buildCommand: npm install && npx prisma generate && npm run build
    startCommand: npx prisma migrate deploy && npm run start
    envVars:
      - key: DATABASE_URL
        sync: false
      - key: LIVEKIT_URL
        sync: false
      - key: LIVEKIT_API_KEY
        sync: false
      - key: LIVEKIT_API_SECRET
        sync: false
      - key: NEXT_PUBLIC_LIVEKIT_URL
        sync: false
      - key: WEBAUTHN_RP_ID
        sync: false
      - key: WEBAUTHN_ORIGIN
        sync: false
      - key: WEBAUTHN_RP_NAME
        value: QuickCall
      - key: SESSION_SECRET
        generateValue: true
      - key: NODE_ENV
        value: production

databases:
  - name: quickcall-db
    plan: free
    databaseName: quickcall
    user: quickcall
```

### 3. デプロイボタンを使う（最速）

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy)

### 4. 環境変数の設定
Renderダッシュボードで以下を設定：

```bash
# LiveKit (https://cloud.livekit.io で取得)
LIVEKIT_URL=wss://your-livekit-url.livekit.cloud
LIVEKIT_API_KEY=APIxxxxxxxx
LIVEKIT_API_SECRET=xxxxxxxxxxxxxxxxxx
NEXT_PUBLIC_LIVEKIT_URL=wss://your-livekit-url.livekit.cloud

# WebAuthn (Renderのドメインに変更)
WEBAUTHN_RP_ID=quickcall.onrender.com
WEBAUTHN_ORIGIN=https://quickcall.onrender.com

# Database (Renderが自動設定)
DATABASE_URL=postgresql://...

# Session
SESSION_SECRET=<自動生成される>
```

## 🚀 Vercelへのデプロイ（Next.js最適化）

### 1. vercel.jsonの作成
```json
{
  "buildCommand": "prisma generate && next build",
  "outputDirectory": ".next",
  "framework": "nextjs",
  "regions": ["iad1"],
  "env": {
    "DATABASE_URL": "@database_url",
    "LIVEKIT_URL": "@livekit_url",
    "LIVEKIT_API_KEY": "@livekit_api_key",
    "LIVEKIT_API_SECRET": "@livekit_api_secret",
    "NEXT_PUBLIC_LIVEKIT_URL": "@next_public_livekit_url"
  }
}
```

### 2. デプロイコマンド
```bash
npx vercel --prod
```

## 🐳 Fly.ioへのデプロイ（グローバル展開）

### 1. fly.tomlの作成
```toml
app = "quickcall-livekit"
primary_region = "nrt"

[build]
  builder = "heroku/buildpacks:20"

[env]
  PORT = "8080"
  NODE_ENV = "production"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = false
  auto_start_machines = true
  min_machines_running = 1

[processes]
  app = "npm run start"

[[services]]
  protocol = "tcp"
  internal_port = 8080

  [[services.ports]]
    port = 80
    handlers = ["http"]

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]
```

### 2. デプロイコマンド
```bash
fly launch
fly deploy
```

## 🌩️ Cloudflare Pagesへのデプロイ

### 1. wrangler.tomlの作成
```toml
name = "quickcall-livekit"
compatibility_date = "2024-01-01"

[site]
bucket = "./.next/static"

[build]
command = "npm run build"

[env.production]
vars = { NODE_ENV = "production" }
```

### 2. デプロイコマンド
```bash
npm install -g wrangler
wrangler pages deploy .next
```

## 🛤️ Railwayへのデプロイ

### 1. railway.jsonの作成
```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm ci && prisma generate && npm run build"
  },
  "deploy": {
    "startCommand": "prisma migrate deploy && npm run start",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3
  }
}
```

### 2. デプロイコマンド
```bash
railway login
railway link
railway up
```

## 📊 各サービスの特徴詳細

### Render
- **メリット**: 完全無料、PostgreSQL付き、自動デプロイ
- **デメリット**: 無料プランはコールドスタート（30分アクセスなしでスリープ）
- **解決策**: UptimeRobotで定期ping

### Vercel
- **メリット**: Next.js最適化、超高速、分析ツール付き
- **デメリット**: サーバーレス（WebSocket制限あり）
- **解決策**: LiveKitはクライアントサイドで接続

### Fly.io
- **メリット**: グローバル展開、低遅延、Docker対応
- **デメリット**: 設定が少し複雑
- **解決策**: テンプレート使用

### Railway
- **メリット**: 超簡単、DB自動設定、開発者フレンドリー
- **デメリット**: 無料枠が$5分のみ
- **解決策**: 軽量アプリなら1ヶ月持つ

### Cloudflare Pages
- **メリット**: 世界最速CDN、DDoS保護、無制限帯域
- **デメリット**: 静的サイト向き
- **解決策**: APIをWorkerで実装

## 🔧 共通設定ファイル

### package.jsonのスクリプト追加
```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "deploy:render": "render-cli deploy",
    "deploy:vercel": "vercel --prod",
    "deploy:fly": "fly deploy",
    "deploy:railway": "railway up",
    "deploy:all": "npm run deploy:render && npm run deploy:vercel"
  }
}
```

### .env.productionの例
```bash
# Production環境用
NODE_ENV=production

# LiveKit本番設定
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=APIxxxxxxxxx
LIVEKIT_API_SECRET=xxxxxxxxxxxxx
NEXT_PUBLIC_LIVEKIT_URL=wss://your-project.livekit.cloud

# カスタムドメイン用
WEBAUTHN_RP_ID=your-domain.com
WEBAUTHN_ORIGIN=https://your-domain.com

# PostgreSQL（本番用）
DATABASE_URL=postgresql://user:password@host:5432/database

# セッション（ランダム生成）
SESSION_SECRET=your-very-long-random-string-here
```

## 🚨 重要な注意事項

### セキュリティ
1. **環境変数は必ずダッシュボードで設定**（コードに含めない）
2. **SESSION_SECRETは必ず変更**
3. **HTTPSを必ず有効化**

### パフォーマンス
1. **データベースは同じリージョンに配置**
2. **CDNを活用**（Cloudflare推奨）
3. **画像最適化**（next/image使用）

### 監視
1. **UptimeRobot**で死活監視
2. **Sentry**でエラー監視
3. **Google Analytics**で利用状況確認

## 📱 デプロイ後のテスト

### 1. 基本機能テスト
```bash
curl https://your-app.onrender.com/api/health
```

### 2. WebSocket接続テスト
```javascript
const ws = new WebSocket('wss://your-livekit.cloud');
ws.onopen = () => console.log('Connected!');
```

### 3. モバイルテスト
- iOS Safari
- Android Chrome
- タブレット

## 🎯 推奨構成

### 小規模（〜100人）
- **Render** + **PostgreSQL** + **Cloudflare CDN**
- コスト: **$0/月**

### 中規模（〜1000人）
- **Vercel Pro** + **Supabase** + **LiveKit Cloud**
- コスト: **$20/月**

### 大規模（1000人以上）
- **AWS/GCP** + **自前LiveKit** + **Redis**
- コスト: **$100+/月**

## 🆘 トラブルシューティング

### ビルドエラー
```bash
# Prismaの再生成
npx prisma generate
rm -rf node_modules
npm install
```

### データベース接続エラー
```bash
# 接続文字列の確認
npx prisma db pull
npx prisma migrate deploy
```

### デプロイ失敗
```bash
# ログ確認
render logs
vercel logs
fly logs
```

## 📚 参考リンク

- [Render Docs](https://render.com/docs)
- [Vercel Docs](https://vercel.com/docs)
- [Fly.io Docs](https://fly.io/docs)
- [Railway Docs](https://docs.railway.app)
- [Cloudflare Pages Docs](https://developers.cloudflare.com/pages)

---

**💡 ヒント**: まずはRenderで試してから、必要に応じて他のサービスに移行するのがおすすめです！