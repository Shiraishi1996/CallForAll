#!/bin/bash

# =====================================================
# QuickCall LiveKit - 自動ポート検索起動
# 空いているポートを自動的に見つけて起動
# =====================================================

echo "🚀 QuickCall LiveKit - 自動ポート検索"

# 使用可能なポートを探す関数
find_available_port() {
    local start_port=${1:-3000}
    local end_port=${2:-3100}

    for port in $(seq $start_port $end_port); do
        if ! lsof -ti:$port >/dev/null 2>&1; then
            echo $port
            return 0
        fi
    done
    return 1
}

# 空いているポートを探す
echo "🔍 利用可能なポートを検索中..."
PORT=$(find_available_port 3000 3100)

if [ -z "$PORT" ]; then
    echo "❌ 利用可能なポートが見つかりません"
    exit 1
fi

echo "✅ ポート $PORT を使用します"

# 環境変数ファイルの作成/更新
if [ ! -f .env ]; then
    cat > .env << EOF
# LiveKit設定（デモ用）
LIVEKIT_URL=wss://meet.livekit.io
LIVEKIT_API_KEY=APIw4Zf8hCQgqBt
LIVEKIT_API_SECRET=UKpboWpMdujPkMHnFQoNRH8vETQuLGhxP3FHo4PWqvRf
NEXT_PUBLIC_LIVEKIT_URL=wss://meet.livekit.io

WEBAUTHN_RP_ID=localhost
WEBAUTHN_ORIGIN=http://localhost:$PORT
WEBAUTHN_RP_NAME=QuickCall
SESSION_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "demo_$(date +%s)")
DATABASE_URL="file:./prisma/dev.db"
PORT=$PORT
EOF
else
    # ポート設定を更新
    sed -i.bak "s/^PORT=.*/PORT=$PORT/" .env 2>/dev/null || echo "PORT=$PORT" >> .env
    sed -i.bak "s|WEBAUTHN_ORIGIN=.*|WEBAUTHN_ORIGIN=http://localhost:$PORT|" .env && rm .env.bak 2>/dev/null || true
fi

# セットアップ
[ ! -d node_modules ] && npm install --silent
npx prisma generate 2>/dev/null
npx prisma db push --accept-data-loss 2>/dev/null || true

# 起動
echo ""
echo "======================================"
echo "🎥 QuickCall LiveKit"
echo "📱 URL: http://localhost:$PORT"
echo "======================================"
echo "停止: Ctrl+C"
echo ""

PORT=$PORT npm run dev