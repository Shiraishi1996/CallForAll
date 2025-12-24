#!/bin/bash

# =====================================================
# QuickCall LiveKit - ngrok公開スクリプト
# ローカルアプリをインターネットに公開
# =====================================================

set -e

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "========================================"
echo "  🌐 QuickCall LiveKit Web公開"
echo "      powered by ngrok"
echo "========================================"
echo -e "${NC}"

# ポート設定
PORT=${1:-3000}

# ngrokのインストール確認と自動インストール
install_ngrok() {
    echo -e "${YELLOW}📦 ngrokをチェック中...${NC}"

    if command -v ngrok &> /dev/null; then
        echo -e "${GREEN}✅ ngrokは既にインストール済み${NC}"
        return 0
    fi

    echo -e "${YELLOW}ngrokがインストールされていません${NC}"
    echo -e "${CYAN}自動インストールしますか？ (y/n)${NC}"
    read -r install_choice

    if [[ "$install_choice" != "y" ]]; then
        echo -e "${RED}ngrokが必要です。手動でインストールしてください:${NC}"
        echo "  macOS: brew install ngrok/ngrok/ngrok"
        echo "  または: https://ngrok.com/download"
        exit 1
    fi

    # OS判定とインストール
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            echo -e "${YELLOW}Homebrewでngrokをインストール中...${NC}"
            brew install ngrok/ngrok/ngrok
        else
            echo -e "${YELLOW}ngrokをダウンロード中...${NC}"
            curl -s https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-darwin-amd64.zip -o ngrok.zip
            unzip -o ngrok.zip
            chmod +x ngrok
            sudo mv ngrok /usr/local/bin/
            rm ngrok.zip
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        echo -e "${YELLOW}ngrokをダウンロード中...${NC}"
        wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
        tar xvzf ngrok-v3-stable-linux-amd64.tgz
        chmod +x ngrok
        sudo mv ngrok /usr/local/bin/
        rm ngrok-v3-stable-linux-amd64.tgz
    else
        echo -e "${RED}お使いのOSでは自動インストールできません${NC}"
        echo "https://ngrok.com/download から手動でインストールしてください"
        exit 1
    fi

    echo -e "${GREEN}✅ ngrokのインストール完了${NC}"
}

# 既存プロセスの終了
cleanup_processes() {
    echo -e "${YELLOW}🔄 既存のプロセスをクリーンアップ中...${NC}"

    # Next.jsプロセスを終了
    pkill -f "node.*next" 2>/dev/null || true

    # ngrokプロセスを終了
    pkill -f ngrok 2>/dev/null || true

    # ポートを解放
    if [[ "$OSTYPE" == "darwin"* ]]; then
        lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
        lsof -ti:4040 | xargs kill -9 2>/dev/null || true  # ngrok web interface
    else
        fuser -k $PORT/tcp 2>/dev/null || true
        fuser -k 4040/tcp 2>/dev/null || true
    fi

    sleep 2
    echo -e "${GREEN}✅ クリーンアップ完了${NC}"
}

# 環境変数の設定
setup_env() {
    echo -e "${YELLOW}⚙️  環境設定中...${NC}"

    if [ ! -f .env ]; then
        cat > .env << EOF
# LiveKit設定（デモ用）
LIVEKIT_URL=wss://meet.livekit.io
LIVEKIT_API_KEY=APIw4Zf8hCQgqBt
LIVEKIT_API_SECRET=UKpboWpMdujPkMHnFQoNRH8vETQuLGhxP3FHo4PWqvRf
NEXT_PUBLIC_LIVEKIT_URL=wss://meet.livekit.io

# WebAuthn設定（ngrokで更新される）
WEBAUTHN_RP_ID=localhost
WEBAUTHN_ORIGIN=http://localhost:$PORT
WEBAUTHN_RP_NAME=QuickCall

# セッション
SESSION_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "demo_$(date +%s)")

# データベース
DATABASE_URL="file:./prisma/dev.db"

# ポート
PORT=$PORT
EOF
    fi

    # ポート設定を更新
    sed -i.bak "s/^PORT=.*/PORT=$PORT/" .env 2>/dev/null && rm .env.bak 2>/dev/null || true
}

# 依存関係とデータベースのセットアップ
setup_app() {
    if [ ! -d node_modules ]; then
        echo -e "${YELLOW}📦 パッケージをインストール中...${NC}"
        npm install
    fi

    echo -e "${YELLOW}🗄️  データベースをセットアップ中...${NC}"
    npx prisma generate 2>/dev/null
    npx prisma db push --accept-data-loss 2>/dev/null || true
}

# アプリケーションとngrokの起動
start_with_ngrok() {
    echo -e "${GREEN}🚀 アプリケーションを起動中...${NC}"

    # Next.jsを起動
    PORT=$PORT npm run dev > /tmp/nextjs.log 2>&1 &
    NEXTJS_PID=$!

    # Next.jsの起動を待つ
    echo -e "${YELLOW}⏳ サーバーの起動を待っています...${NC}"
    for i in {1..30}; do
        if curl -s http://localhost:$PORT > /dev/null 2>&1; then
            echo -e "${GREEN}✅ サーバーが起動しました${NC}"
            break
        fi
        sleep 1
        echo -n "."
    done
    echo ""

    # ngrokを起動
    echo -e "${MAGENTA}🌐 ngrokでトンネルを作成中...${NC}"

    # ngrokをバックグラウンドで起動
    ngrok http $PORT --log=stdout > /tmp/ngrok.log 2>&1 &
    NGROK_PID=$!

    # ngrokの起動を待つ
    sleep 3

    # ngrok APIからパブリックURLを取得
    echo -e "${YELLOW}📡 公開URLを取得中...${NC}"

    # 複数の方法でURLを取得
    NGROK_URL=""

    # 方法1: ngrok APIから取得
    for i in {1..10}; do
        NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*' | grep -o 'https://[^"]*' | head -1)
        if [ -n "$NGROK_URL" ]; then
            break
        fi
        sleep 1
    done

    # 方法2: ログファイルから取得（フォールバック）
    if [ -z "$NGROK_URL" ]; then
        NGROK_URL=$(grep -o 'https://.*\.ngrok.*\.app' /tmp/ngrok.log 2>/dev/null | head -1 || true)
    fi

    # 結果表示
    echo ""
    echo -e "${GREEN}========================================"
    echo -e "${GREEN}   ✨ デプロイ成功！"
    echo -e "${GREEN}========================================"
    echo -e "${NC}"

    echo -e "${CYAN}📱 ローカルURL:${NC}"
    echo -e "   ${BLUE}http://localhost:$PORT${NC}"
    echo ""

    if [ -n "$NGROK_URL" ]; then
        echo -e "${CYAN}🌐 公開URL（世界中からアクセス可能）:${NC}"
        echo -e "   ${GREEN}${NGROK_URL}${NC}"
        echo ""
        echo -e "${YELLOW}📋 URLをコピー:${NC}"
        echo "   ${NGROK_URL}"
        echo ""

        # QRコードのリンク（オプション）
        echo -e "${MAGENTA}📱 モバイルでアクセス:${NC}"
        echo "   QRコード: https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${NGROK_URL}"

        # 環境変数を更新（Passkeyのため）
        NGROK_DOMAIN=$(echo $NGROK_URL | sed 's|https://||' | sed 's|/.*||')
        sed -i.bak "s|WEBAUTHN_RP_ID=.*|WEBAUTHN_RP_ID=${NGROK_DOMAIN}|" .env 2>/dev/null && rm .env.bak 2>/dev/null || true
        sed -i.bak "s|WEBAUTHN_ORIGIN=.*|WEBAUTHN_ORIGIN=${NGROK_URL}|" .env 2>/dev/null && rm .env.bak 2>/dev/null || true
    else
        echo -e "${YELLOW}⚠️  公開URLの自動取得に失敗しました${NC}"
        echo -e "${CYAN}ngrok Web Interface で確認:${NC}"
        echo "   http://localhost:4040"
    fi

    echo ""
    echo -e "${GREEN}========================================"
    echo -e "${NC}"
    echo -e "${CYAN}📊 ngrok管理画面:${NC} http://localhost:4040"
    echo -e "${CYAN}📝 ログ:${NC}"
    echo "   Next.js: tail -f /tmp/nextjs.log"
    echo "   ngrok:   tail -f /tmp/ngrok.log"
    echo ""
    echo -e "${YELLOW}⚠️  注意事項:${NC}"
    echo "  • ngrokの無料版は8時間で切断されます"
    echo "  • URLは起動のたびに変わります"
    echo "  • HTTPSで自動的に保護されています"
    echo ""
    echo -e "${RED}🛑 停止: Ctrl+C${NC}"

    # シグナルハンドラー
    trap "echo -e '\n${YELLOW}停止中...${NC}'; kill $NEXTJS_PID $NGROK_PID 2>/dev/null; exit" INT TERM

    # プロセスを待つ
    wait $NEXTJS_PID
}

# メイン処理
main() {
    # ngrokのインストール確認
    install_ngrok

    # 既存プロセスのクリーンアップ
    cleanup_processes

    # 環境設定
    setup_env

    # アプリケーションのセットアップ
    setup_app

    # 起動
    start_with_ngrok
}

# 実行
main