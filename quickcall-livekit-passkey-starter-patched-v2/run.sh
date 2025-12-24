#!/bin/bash

# =====================================================
# QuickCall - 超シンプル起動スクリプト
# 一発ですべてセットアップして起動
# =====================================================

echo "🚀 QuickCall LiveKit を起動します..."

# .envファイルが存在しない場合は作成
if [ ! -f .env ]; then
    echo "📝 環境設定ファイルを作成中..."
    cat > .env << 'EOF'
# デモ用の設定（後で変更してください）
LIVEKIT_URL=wss://demo.livekit.cloud
LIVEKIT_API_KEY=APIKxxxxxxxxxxx
LIVEKIT_API_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxx
NEXT_PUBLIC_LIVEKIT_URL=wss://demo.livekit.cloud
WEBAUTHN_RP_ID=localhost
WEBAUTHN_ORIGIN=http://localhost:3000
WEBAUTHN_RP_NAME=QuickCall
SESSION_SECRET=demo_secret_change_me_in_production_$(date +%s)
DATABASE_URL="file:./prisma/dev.db"
EOF
fi

# 依存関係インストール
echo "📦 パッケージをインストール中..."
npm install --silent

# Prismaセットアップ
echo "🗄️ データベースをセットアップ中..."
npx prisma generate --silent
npx prisma migrate dev --name init --skip-seed 2>/dev/null || npx prisma db push --accept-data-loss

# ビルド
echo "🔨 アプリケーションをビルド中..."
npm run build

# 起動
echo "✅ 起動完了！"
echo "📱 ブラウザで開く: http://localhost:3000"
echo ""
echo "停止: Ctrl+C"
echo ""

# アプリケーション起動
npm run start