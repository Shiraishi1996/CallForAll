#!/bin/bash

# =====================================================
# QuickCall LiveKit - 強制起動スクリプト
# 既存プロセスを自動的にkillして起動
# =====================================================

echo "🚀 QuickCall LiveKit - 強制起動モード"

# ポート指定（引数または環境変数、デフォルト3000）
PORT=${1:-${PORT:-3000}}

# 既存のNext.jsプロセスを全て終了
echo "🔄 既存のプロセスを終了中..."
pkill -f "node.*next" 2>/dev/null || true

# ポート3000を使用しているプロセスを終了
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
else
    # Linux
    fuser -k $PORT/tcp 2>/dev/null || true
fi

sleep 1

# 環境変数ファイルの作成/更新
if [ ! -f .env ]; then
    cat > .env << EOF
# LiveKit設定（デモ用）
LIVEKIT_URL=wss://meet.livekit.io
LIVEKIT_API_KEY=APIw4Zf8hCQgqBt
LIVEKIT_API_SECRET=UKpboWpMdujPkMHnFQoNRH8vETQuLGhxP3FHo4PWqvRf
NEXT_PUBLIC_LIVEKIT_URL=wss://meet.livekit.io

# WebAuthn設定
WEBAUTHN_RP_ID=localhost
WEBAUTHN_ORIGIN=http://localhost:$PORT
WEBAUTHN_RP_NAME=QuickCall

# セッション
SESSION_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "demo_$(date +%s)")

# DB
DATABASE_URL="file:./prisma/dev.db"

# ポート
PORT=$PORT
EOF
fi

# 依存関係チェック
[ ! -d node_modules ] && npm install

# Prisma
npx prisma generate 2>/dev/null
npx prisma db push --accept-data-loss 2>/dev/null || true

# 起動
echo "✅ ポート $PORT で起動中..."
echo "📱 URL: http://localhost:$PORT"
echo ""

PORT=$PORT npm run dev