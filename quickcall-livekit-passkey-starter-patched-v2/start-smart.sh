#!/bin/bash

# =====================================================
# QuickCall LiveKit - スマート起動スクリプト
# 自動的にポート競合を解決して起動
# =====================================================

set -e

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# デフォルトポート
DEFAULT_PORT=3000
PORT=$DEFAULT_PORT

# 使用するポート（引数で指定可能）
if [ ! -z "$1" ]; then
    PORT=$1
fi

echo -e "${GREEN}🚀 QuickCall LiveKit - スマート起動${NC}"
echo ""

# ポート競合を解決する関数
kill_port() {
    local port=$1
    echo -e "${YELLOW}ポート $port をチェック中...${NC}"

    # macOSとLinuxで異なるコマンドを使用
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        local pid=$(lsof -ti:$port 2>/dev/null || true)
    else
        # Linux
        local pid=$(lsof -ti:$port 2>/dev/null || fuser -n tcp $port 2>/dev/null | tr -d ' ' || true)
    fi

    if [ ! -z "$pid" ]; then
        echo -e "${YELLOW}ポート $port は使用中 (PID: $pid)${NC}"
        echo -e "${RED}プロセスを終了しますか？ (y/n/p)${NC}"
        echo "  y: 終了して続行"
        echo "  n: キャンセル"
        echo "  p: 別のポートを使用"

        read -r response
        case $response in
            [yY])
                echo -e "${YELLOW}プロセス $pid を終了中...${NC}"
                kill -9 $pid 2>/dev/null || true
                sleep 1
                echo -e "${GREEN}✅ ポート $port が解放されました${NC}"
                ;;
            [pP])
                # 空いているポートを探す
                for try_port in {3001..3010}; do
                    if ! lsof -ti:$try_port >/dev/null 2>&1; then
                        PORT=$try_port
                        echo -e "${GREEN}✅ ポート $PORT を使用します${NC}"
                        break
                    fi
                done
                ;;
            *)
                echo -e "${RED}キャンセルしました${NC}"
                exit 0
                ;;
        esac
    else
        echo -e "${GREEN}✅ ポート $port は利用可能です${NC}"
    fi
}

# Next.jsのプロセスを全て終了する関数
kill_all_next() {
    echo -e "${YELLOW}既存のNext.jsプロセスをチェック中...${NC}"

    # Next.jsプロセスを探す
    local pids=$(pgrep -f "node.*next" 2>/dev/null || true)

    if [ ! -z "$pids" ]; then
        echo -e "${YELLOW}Next.jsプロセスが見つかりました${NC}"
        echo -e "${RED}全て終了しますか？ (y/n)${NC}"
        read -r response

        if [[ "$response" =~ ^[yY]$ ]]; then
            pkill -f "node.*next" 2>/dev/null || true
            sleep 1
            echo -e "${GREEN}✅ Next.jsプロセスを終了しました${NC}"
        fi
    fi
}

# 環境変数ファイルの作成/更新
setup_env() {
    if [ ! -f .env ]; then
        echo -e "${YELLOW}📝 環境設定を作成中...${NC}"
        cat > .env << EOF
# LiveKit設定（デモ用）
LIVEKIT_URL=wss://meet.livekit.io
LIVEKIT_API_KEY=APIw4Zf8hCQgqBt
LIVEKIT_API_SECRET=UKpboWpMdujPkMHnFQoNRH8vETQuLGhxP3FHo4PWqvRf
NEXT_PUBLIC_LIVEKIT_URL=wss://meet.livekit.io

# WebAuthn (Passkey) 設定
WEBAUTHN_RP_ID=localhost
WEBAUTHN_ORIGIN=http://localhost:$PORT
WEBAUTHN_RP_NAME=QuickCall

# セッション管理
SESSION_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "demo_secret_$(date +%s)")

# データベース
DATABASE_URL="file:./prisma/dev.db"

# ポート設定
PORT=$PORT
EOF
        echo -e "${GREEN}✅ 環境設定完了${NC}"
    else
        # ポート設定を更新
        if grep -q "^PORT=" .env; then
            sed -i.bak "s/^PORT=.*/PORT=$PORT/" .env && rm .env.bak
        else
            echo "PORT=$PORT" >> .env
        fi

        # WEBAUTHN_ORIGINも更新
        sed -i.bak "s|WEBAUTHN_ORIGIN=.*|WEBAUTHN_ORIGIN=http://localhost:$PORT|" .env && rm .env.bak
    fi
}

# メインメニュー
echo -e "${BLUE}起動オプションを選択してください:${NC}"
echo "1) 自動モード（ポート競合を自動解決）"
echo "2) 強制モード（既存プロセスを全て終了）"
echo "3) カスタムポート指定"
echo "4) セーフモード（競合チェックのみ）"

read -p "選択 (1-4): " mode

case $mode in
    1)
        echo -e "${GREEN}=== 自動モード ===${NC}"
        kill_port $PORT
        ;;
    2)
        echo -e "${RED}=== 強制モード ===${NC}"
        kill_all_next
        kill_port $PORT
        ;;
    3)
        echo -e "${BLUE}=== カスタムポート ===${NC}"
        read -p "ポート番号を入力 (3000-9999): " custom_port
        if [[ $custom_port =~ ^[0-9]+$ ]] && [ $custom_port -ge 3000 ] && [ $custom_port -le 9999 ]; then
            PORT=$custom_port
            kill_port $PORT
        else
            echo -e "${RED}無効なポート番号です${NC}"
            exit 1
        fi
        ;;
    4)
        echo -e "${BLUE}=== セーフモード ===${NC}"
        if lsof -ti:$PORT >/dev/null 2>&1; then
            echo -e "${RED}ポート $PORT は使用中です${NC}"
            echo "別のポートを使用するか、既存のプロセスを手動で終了してください"
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}無効な選択です${NC}"
        exit 1
        ;;
esac

# 環境設定
setup_env

# 依存関係のインストール
if [ ! -d node_modules ]; then
    echo -e "${YELLOW}📦 パッケージをインストール中...${NC}"
    npm install
fi

# Prismaセットアップ
echo -e "${YELLOW}🗄️ データベースをセットアップ中...${NC}"
npx prisma generate 2>/dev/null
npx prisma migrate dev --name init --skip-seed 2>/dev/null || npx prisma db push --accept-data-loss 2>/dev/null || true

# 起動
echo ""
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}🎥 QuickCall LiveKit ビデオ通話アプリ${NC}"
echo -e "${BLUE}📱 URL: http://localhost:$PORT${NC}"
echo -e "${GREEN}===========================================${NC}"
echo ""
echo -e "${YELLOW}機能:${NC}"
echo "  🎥 ビデオ通話"
echo "  🎤 音声通話"
echo "  💬 チャット"
echo "  📱 画面共有"
echo ""
echo -e "${YELLOW}停止: Ctrl+C または ./stop.sh${NC}"
echo ""

# ポート番号を環境変数として渡して起動
PORT=$PORT npm run dev