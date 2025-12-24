#!/bin/bash

# =====================================================
# QuickCall LiveKit - シンプルデプロイスクリプト
# ngrokを使用してローカルからインターネットに公開
# =====================================================

set -e

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ロゴ
echo -e "${GREEN}"
echo "====================================="
echo "  QuickCall LiveKit Quick Deploy"
echo "====================================="
echo -e "${NC}"

# 環境変数の自動設定
setup_env() {
    echo -e "${YELLOW}環境設定を開始します...${NC}"

    # .envファイルが存在しない場合は作成
    if [ ! -f .env ]; then
        echo -e "${YELLOW}.envファイルを作成中...${NC}"

        # SESSION_SECRETの自動生成
        SESSION_SECRET=$(openssl rand -hex 32)

        cat > .env << EOF
# LiveKit Cloud (デモ用の設定)
# 本番環境では https://cloud.livekit.io でアカウント作成して取得
LIVEKIT_URL=wss://demo.livekit.cloud
LIVEKIT_API_KEY=APIKxxxxxxxxxxx
LIVEKIT_API_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxx
NEXT_PUBLIC_LIVEKIT_URL=wss://demo.livekit.cloud

# WebAuthn (Passkey) - ngrok用に後で自動更新されます
WEBAUTHN_RP_ID=localhost
WEBAUTHN_ORIGIN=http://localhost:3000
WEBAUTHN_RP_NAME=QuickCall

# App session
SESSION_SECRET=${SESSION_SECRET}

# Database (SQLite - 即座に使用可能)
DATABASE_URL="file:./prisma/dev.db"
EOF
        echo -e "${GREEN}.envファイルを作成しました${NC}"
    fi
}

# 依存関係のインストール
install_deps() {
    echo -e "${YELLOW}依存関係をインストール中...${NC}"

    # package-lock.jsonが存在する場合はci、そうでなければinstall
    if [ -f package-lock.json ]; then
        npm ci
    else
        npm install
    fi

    echo -e "${GREEN}依存関係のインストール完了✓${NC}"
}

# Prismaのセットアップ
setup_database() {
    echo -e "${YELLOW}データベースをセットアップ中...${NC}"

    # Prismaクライアントの生成
    npx prisma generate

    # マイグレーションの実行
    npx prisma migrate dev --name init --skip-seed

    echo -e "${GREEN}データベースのセットアップ完了✓${NC}"
}

# ビルド
build_app() {
    echo -e "${YELLOW}アプリケーションをビルド中...${NC}"
    npm run build
    echo -e "${GREEN}ビルド完了✓${NC}"
}

# ngrokのインストール確認
check_ngrok() {
    if ! command -v ngrok &> /dev/null; then
        echo -e "${YELLOW}ngrokがインストールされていません${NC}"
        echo "ngrokをインストールしますか? (y/n)"
        read install_ngrok

        if [ "$install_ngrok" = "y" ]; then
            # OS判定
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                if command -v brew &> /dev/null; then
                    brew install ngrok/ngrok/ngrok
                else
                    echo "Homebrewがインストールされていません"
                    echo "https://ngrok.com/download から手動でインストールしてください"
                    exit 1
                fi
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                # Linux
                curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
                echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
                sudo apt update && sudo apt install ngrok
            else
                echo "お使いのOSでは自動インストールできません"
                echo "https://ngrok.com/download から手動でインストールしてください"
                exit 1
            fi
        else
            echo -e "${RED}ngrokが必要です。インストール後に再実行してください${NC}"
            exit 1
        fi
    fi
}

# アプリケーションの起動
start_app() {
    echo -e "${GREEN}アプリケーションを起動します...${NC}"
    echo -e "${YELLOW}ブラウザで http://localhost:3000 にアクセスできます${NC}"

    # バックグラウンドでNext.jsを起動
    npm run start &
    APP_PID=$!

    # 少し待機
    sleep 5

    # ngrokで公開
    echo -e "${YELLOW}ngrokでインターネットに公開中...${NC}"

    # ngrokを起動（フォアグラウンドで実行）
    ngrok http 3000 --log=stdout > ngrok.log 2>&1 &
    NGROK_PID=$!

    # ngrokのURLを取得
    sleep 3

    # ngrok APIからURL取得を試みる
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*' | grep -o 'https://[^"]*' | head -1)

    if [ -n "$NGROK_URL" ]; then
        echo -e "${GREEN}"
        echo "====================================="
        echo "  デプロイ成功！"
        echo "====================================="
        echo -e "${NC}"
        echo -e "${BLUE}ローカルURL:${NC} http://localhost:3000"
        echo -e "${BLUE}公開URL:${NC} ${NGROK_URL}"
        echo ""
        echo -e "${YELLOW}重要: WebAuthn (Passkey)を使用する場合は、"
        echo ".envファイルの以下の設定を更新してください:${NC}"
        echo "WEBAUTHN_RP_ID=$(echo $NGROK_URL | sed 's|https://||' | sed 's|/.*||')"
        echo "WEBAUTHN_ORIGIN=$NGROK_URL"
        echo ""
        echo -e "${GREEN}Ctrl+Cで停止${NC}"
    else
        echo -e "${YELLOW}ngrokのURLを自動取得できませんでした${NC}"
        echo "ngrokのコンソールで確認してください"
        echo -e "${GREEN}Ctrl+Cで停止${NC}"
    fi

    # シグナルハンドラー
    trap cleanup INT TERM

    # 待機
    wait $APP_PID
}

# クリーンアップ処理
cleanup() {
    echo -e "\n${YELLOW}アプリケーションを停止中...${NC}"

    if [ -n "$APP_PID" ]; then
        kill $APP_PID 2>/dev/null || true
    fi

    if [ -n "$NGROK_PID" ]; then
        kill $NGROK_PID 2>/dev/null || true
    fi

    # Node.jsプロセスをすべて終了（念のため）
    pkill -f "node.*next" 2>/dev/null || true
    pkill -f ngrok 2>/dev/null || true

    echo -e "${GREEN}停止完了${NC}"
    exit 0
}

# ワンライナー実行
one_liner() {
    echo -e "${BLUE}=== ワンライナー実行モード ===${NC}"

    # すべてを自動実行
    setup_env
    install_deps
    setup_database
    build_app
    check_ngrok
    start_app
}

# インタラクティブモード
interactive_mode() {
    echo -e "${BLUE}=== インタラクティブモード ===${NC}"

    echo "実行するステップを選択してください:"
    echo "1) すべて実行（推奨）"
    echo "2) 環境設定のみ"
    echo "3) ビルドのみ"
    echo "4) 起動のみ"

    read -p "選択 (1-4): " choice

    case $choice in
        1)
            setup_env
            install_deps
            setup_database
            build_app
            check_ngrok
            start_app
            ;;
        2)
            setup_env
            ;;
        3)
            install_deps
            setup_database
            build_app
            ;;
        4)
            check_ngrok
            start_app
            ;;
        *)
            echo -e "${RED}無効な選択です${NC}"
            exit 1
            ;;
    esac
}

# メイン処理
main() {
    # 引数チェック
    if [ "$1" = "--auto" ] || [ "$1" = "-a" ]; then
        one_liner
    else
        interactive_mode
    fi
}

# 実行
main "$@"