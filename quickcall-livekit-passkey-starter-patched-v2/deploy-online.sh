#!/bin/bash

# =====================================================
# インターネット公開用デプロイスクリプト
# ngrok / Cloudflare Tunnel / localtunnel から選択可能
# =====================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}QuickCall LiveKit - オンラインデプロイ${NC}"
echo ""

# プロセスIDを保存
APP_PID=""
TUNNEL_PID=""

# クリーンアップ関数
cleanup() {
    echo -e "\n${YELLOW}停止中...${NC}"
    [ -n "$APP_PID" ] && kill $APP_PID 2>/dev/null || true
    [ -n "$TUNNEL_PID" ] && kill $TUNNEL_PID 2>/dev/null || true
    pkill -f "node.*next" 2>/dev/null || true
    echo -e "${GREEN}停止完了${NC}"
    exit 0
}

trap cleanup INT TERM

# 初期セットアップ
initial_setup() {
    # .envファイル作成
    if [ ! -f .env ]; then
        echo -e "${YELLOW}.envファイルを作成中...${NC}"
        cat > .env << 'EOF'
LIVEKIT_URL=wss://demo.livekit.cloud
LIVEKIT_API_KEY=APIKxxxxxxxxxxx
LIVEKIT_API_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxx
NEXT_PUBLIC_LIVEKIT_URL=wss://demo.livekit.cloud
WEBAUTHN_RP_ID=localhost
WEBAUTHN_ORIGIN=http://localhost:3000
WEBAUTHN_RP_NAME=QuickCall
SESSION_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "demo_secret_$(date +%s)")
DATABASE_URL="file:./prisma/dev.db"
EOF
    fi

    # 依存関係インストール
    echo -e "${YELLOW}セットアップ中...${NC}"
    npm install --silent 2>/dev/null || npm install

    # Prisma
    npx prisma generate --silent 2>/dev/null || npx prisma generate
    npx prisma migrate dev --name init --skip-seed 2>/dev/null || npx prisma db push --accept-data-loss

    # ビルド
    echo -e "${YELLOW}ビルド中...${NC}"
    npm run build
}

# ngrokで公開
deploy_ngrok() {
    # ngrokインストール確認
    if ! command -v ngrok &> /dev/null; then
        echo -e "${RED}ngrokがインストールされていません${NC}"

        # OS別インストール
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "インストールコマンド: brew install ngrok/ngrok/ngrok"
        else
            echo "インストール: https://ngrok.com/download"
        fi
        exit 1
    fi

    # アプリ起動
    npm run start &
    APP_PID=$!
    sleep 3

    # ngrok起動
    echo -e "${YELLOW}ngrokで公開中...${NC}"
    ngrok http 3000 --log=stdout > /tmp/ngrok.log 2>&1 &
    TUNNEL_PID=$!

    sleep 3

    # URL取得
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*' | grep -o 'https://[^"]*' | head -1)

    if [ -n "$NGROK_URL" ]; then
        echo -e "${GREEN}====================================${NC}"
        echo -e "${GREEN}デプロイ成功！${NC}"
        echo -e "${BLUE}ローカル:${NC} http://localhost:3000"
        echo -e "${BLUE}公開URL:${NC} ${NGROK_URL}"
        echo -e "${GREEN}====================================${NC}"
    else
        echo -e "${YELLOW}ngrok起動中... 数秒お待ちください${NC}"
        tail -f /tmp/ngrok.log | grep -m1 "started tunnel" && echo ""
        echo -e "${GREEN}ngrokダッシュボード: http://localhost:4040${NC}"
    fi

    wait $APP_PID
}

# localtunnelで公開
deploy_localtunnel() {
    # localtunnelインストール
    if ! command -v lt &> /dev/null; then
        echo -e "${YELLOW}localtunnelをインストール中...${NC}"
        npm install -g localtunnel
    fi

    # アプリ起動
    npm run start &
    APP_PID=$!
    sleep 3

    # localtunnel起動
    echo -e "${YELLOW}localtunnelで公開中...${NC}"
    lt --port 3000 --subdomain quickcall-$(date +%s) &
    TUNNEL_PID=$!

    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}デプロイ成功！${NC}"
    echo -e "${BLUE}ローカル:${NC} http://localhost:3000"
    echo -e "${YELLOW}公開URLは上記に表示されます${NC}"
    echo -e "${GREEN}====================================${NC}"

    wait $APP_PID
}

# Cloudflare Tunnelで公開
deploy_cloudflare() {
    # cloudflaredインストール確認
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${RED}cloudflaredがインストールされていません${NC}"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "インストール: brew install cloudflare/cloudflare/cloudflared"
        else
            echo "インストール: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
        fi
        exit 1
    fi

    # アプリ起動
    npm run start &
    APP_PID=$!
    sleep 3

    # Cloudflare Tunnel起動
    echo -e "${YELLOW}Cloudflare Tunnelで公開中...${NC}"
    cloudflared tunnel --url http://localhost:3000 &
    TUNNEL_PID=$!

    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}デプロイ成功！${NC}"
    echo -e "${BLUE}ローカル:${NC} http://localhost:3000"
    echo -e "${YELLOW}公開URLは上記に表示されます${NC}"
    echo -e "${GREEN}====================================${NC}"

    wait $APP_PID
}

# メイン処理
main() {
    # 初期セットアップ
    initial_setup

    # トンネルサービス選択
    echo ""
    echo "公開方法を選択してください:"
    echo "1) ngrok (推奨)"
    echo "2) localtunnel"
    echo "3) Cloudflare Tunnel"
    echo "4) ローカルのみ（localhost:3000）"

    read -p "選択 (1-4): " choice

    case $choice in
        1) deploy_ngrok ;;
        2) deploy_localtunnel ;;
        3) deploy_cloudflare ;;
        4)
            npm run start &
            APP_PID=$!
            echo -e "${GREEN}起動完了: http://localhost:3000${NC}"
            wait $APP_PID
            ;;
        *)
            echo -e "${RED}無効な選択です${NC}"
            exit 1
            ;;
    esac
}

# 引数処理
if [ "$1" = "--ngrok" ]; then
    initial_setup
    deploy_ngrok
elif [ "$1" = "--localtunnel" ] || [ "$1" = "--lt" ]; then
    initial_setup
    deploy_localtunnel
elif [ "$1" = "--cloudflare" ] || [ "$1" = "--cf" ]; then
    initial_setup
    deploy_cloudflare
elif [ "$1" = "--local" ]; then
    initial_setup
    npm run start
else
    main
fi