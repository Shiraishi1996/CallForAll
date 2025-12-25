#!/bin/bash

# =====================================================
# QuickCall LiveKit - モバイル対応公開スクリプト
# QRコード生成とモバイルアクセス最適化
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
echo "  📱 QuickCall モバイル対応公開"
echo "      QRコード自動生成"
echo "========================================"
echo -e "${NC}"

# ポート設定
PORT=${1:-3000}

# QRコード生成ツールのインストール確認
install_qr_tools() {
    if command -v qrencode &> /dev/null; then
        return 0
    fi

    echo -e "${YELLOW}QRコード生成ツールをインストール中...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install qrencode 2>/dev/null || true
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get install -y qrencode 2>/dev/null || true
    fi
}

# ターミナルでQRコードを表示
show_qr_terminal() {
    local url=$1

    echo -e "${MAGENTA}========================================"
    echo -e "    📱 スマートフォンでスキャン"
    echo -e "========================================${NC}"

    # qrencodeがある場合はターミナルにQRコードを表示
    if command -v qrencode &> /dev/null; then
        qrencode -t ANSIUTF8 "$url"
    else
        # ASCII artでシンプルなQRコード風の表示
        echo ""
        echo "  ████████████████████████████████"
        echo "  ██                            ██"
        echo "  ██  ▄▄▄▄▄ █▀▀▀█ ▄▄▄▄▄        ██"
        echo "  ██  █   █ █   █ █   █        ██"
        echo "  ██  █▄▄▄█ █   █ █▄▄▄█        ██"
        echo "  ██  ▄▄▄▄▄ █   █ ▄▄▄▄▄        ██"
        echo "  ██  █████ █   █ █████        ██"
        echo "  ██                            ██"
        echo "  ████████████████████████████████"
        echo ""
        echo -e "${YELLOW}QRコードは以下のURLで生成できます:${NC}"
    fi
}

# HTMLファイルでQRコード表示ページを生成
generate_qr_html() {
    local ngrok_url=$1
    local local_url="http://localhost:$PORT"

    cat > mobile-access.html << EOF
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>QuickCall - モバイルアクセス</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 400px;
            width: 100%;
            padding: 30px;
            text-align: center;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 28px;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 14px;
        }
        .qr-container {
            background: #f8f9fa;
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 25px;
        }
        .qr-code {
            width: 250px;
            height: 250px;
            margin: 0 auto;
            background: white;
            padding: 10px;
            border-radius: 10px;
        }
        .qr-code img {
            width: 100%;
            height: 100%;
        }
        .url-container {
            background: #f0f0f0;
            border-radius: 10px;
            padding: 15px;
            margin-bottom: 20px;
            word-break: break-all;
        }
        .url-label {
            font-size: 12px;
            color: #999;
            margin-bottom: 5px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .url {
            color: #667eea;
            text-decoration: none;
            font-size: 14px;
            font-weight: 500;
        }
        .button {
            display: inline-block;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 12px 30px;
            border-radius: 25px;
            text-decoration: none;
            font-weight: 600;
            margin-top: 10px;
            transition: transform 0.2s;
        }
        .button:hover {
            transform: translateY(-2px);
        }
        .features {
            margin-top: 30px;
            text-align: left;
        }
        .feature {
            display: flex;
            align-items: center;
            margin-bottom: 15px;
        }
        .feature-icon {
            width: 40px;
            height: 40px;
            background: #f0f0f0;
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-right: 15px;
            font-size: 20px;
        }
        .feature-text {
            flex: 1;
        }
        .feature-title {
            font-weight: 600;
            color: #333;
            margin-bottom: 2px;
        }
        .feature-desc {
            font-size: 12px;
            color: #666;
        }
        .instructions {
            background: #fff3cd;
            border: 1px solid #ffeaa7;
            border-radius: 10px;
            padding: 15px;
            margin-top: 20px;
            font-size: 13px;
            color: #856404;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📱 QuickCall</h1>
        <p class="subtitle">ビデオ通話アプリケーション</p>

        <div class="qr-container">
            <div class="qr-code">
                <img src="https://api.qrserver.com/v1/create-qr-code/?size=500x500&data=${ngrok_url}" alt="QR Code">
            </div>
            <p style="margin-top: 15px; color: #666; font-size: 13px;">
                📷 カメラでQRコードをスキャン
            </p>
        </div>

        <div class="url-container">
            <div class="url-label">公開URL</div>
            <a href="${ngrok_url}" class="url" target="_blank">${ngrok_url}</a>
        </div>

        <a href="${ngrok_url}" class="button" target="_blank">
            🚀 アプリを開く
        </a>

        <div class="features">
            <div class="feature">
                <div class="feature-icon">🎥</div>
                <div class="feature-text">
                    <div class="feature-title">ビデオ通話</div>
                    <div class="feature-desc">高品質なビデオ通話</div>
                </div>
            </div>
            <div class="feature">
                <div class="feature-icon">🎤</div>
                <div class="feature-text">
                    <div class="feature-title">音声通話</div>
                    <div class="feature-desc">クリアな音声通信</div>
                </div>
            </div>
            <div class="feature">
                <div class="feature-icon">💬</div>
                <div class="feature-text">
                    <div class="feature-title">チャット</div>
                    <div class="feature-desc">リアルタイムメッセージ</div>
                </div>
            </div>
            <div class="feature">
                <div class="feature-icon">📱</div>
                <div class="feature-text">
                    <div class="feature-title">モバイル対応</div>
                    <div class="feature-desc">スマホ・タブレット対応</div>
                </div>
            </div>
        </div>

        <div class="instructions">
            <strong>📌 使い方:</strong><br>
            1. QRコードをスキャンまたは「アプリを開く」をタップ<br>
            2. ルームIDを入力または生成<br>
            3. 「Join」で通話開始<br>
            4. 同じルームIDを共有して複数人で参加
        </div>
    </div>

    <script>
        // 自動でURLをコピーボタンを追加
        document.addEventListener('DOMContentLoaded', function() {
            const urlContainer = document.querySelector('.url-container');
            const copyBtn = document.createElement('button');
            copyBtn.textContent = '📋 URLをコピー';
            copyBtn.style.cssText = 'background: #667eea; color: white; border: none; padding: 8px 15px; border-radius: 5px; margin-top: 10px; cursor: pointer;';
            copyBtn.onclick = function() {
                navigator.clipboard.writeText('${ngrok_url}').then(() => {
                    copyBtn.textContent = '✅ コピー完了！';
                    setTimeout(() => {
                        copyBtn.textContent = '📋 URLをコピー';
                    }, 2000);
                });
            };
            urlContainer.appendChild(copyBtn);
        });
    </script>
</body>
</html>
EOF

    echo -e "${GREEN}✅ mobile-access.html を生成しました${NC}"
}

# 既存プロセスのクリーンアップ
cleanup() {
    echo -e "${YELLOW}🔄 クリーンアップ中...${NC}"
    pkill -f "node.*next" 2>/dev/null || true
    pkill -f ngrok 2>/dev/null || true

    if [[ "$OSTYPE" == "darwin"* ]]; then
        lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
    else
        fuser -k $PORT/tcp 2>/dev/null || true
    fi

    sleep 2
}

# 環境設定
setup_env() {
    if [ ! -f .env ]; then
        cat > .env << EOF
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
    fi
}

# アプリ起動とngrok
start_app() {
    # 依存関係
    [ ! -d node_modules ] && npm install

    # データベース
    npx prisma generate 2>/dev/null
    npx prisma db push --accept-data-loss 2>/dev/null || true

    # Next.js起動
    echo -e "${GREEN}🚀 アプリケーションを起動中...${NC}"
    PORT=$PORT npm run dev > /tmp/nextjs.log 2>&1 &
    NEXTJS_PID=$!

    # 起動待機
    for i in {1..30}; do
        if curl -s http://localhost:$PORT > /dev/null 2>&1; then
            break
        fi
        sleep 1
        echo -n "."
    done
    echo ""

    # ngrok起動
    echo -e "${MAGENTA}🌐 ngrokでトンネル作成中...${NC}"
    ngrok http $PORT --log=stdout > /tmp/ngrok.log 2>&1 &
    NGROK_PID=$!

    sleep 3

    # URL取得
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*' | grep -o 'https://[^"]*' | head -1)

    if [ -z "$NGROK_URL" ]; then
        NGROK_URL=$(grep -o 'https://.*\.ngrok.*\.app' /tmp/ngrok.log 2>/dev/null | head -1 || true)
    fi

    # 結果表示
    clear
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════╗"
    echo "║     📱 QuickCall モバイルアクセス      ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"

    if [ -n "$NGROK_URL" ]; then
        # QRコード表示
        show_qr_terminal "$NGROK_URL"

        # HTML生成
        generate_qr_html "$NGROK_URL"

        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${GREEN}📱 モバイルアクセスURL:${NC}"
        echo -e "   ${BLUE}$NGROK_URL${NC}"
        echo ""
        echo -e "${YELLOW}📄 QRコードページ:${NC}"
        echo -e "   file://$(pwd)/mobile-access.html"
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # モバイル用の短縮URL情報
        echo ""
        echo -e "${MAGENTA}📲 スマートフォンからのアクセス方法:${NC}"
        echo ""
        echo "  1️⃣  上記のQRコードをカメラでスキャン"
        echo "  2️⃣  または、URLを直接入力"
        echo "  3️⃣  または、mobile-access.htmlをブラウザで開く"
        echo ""

        # ブラウザで自動的にQRコードページを開く（macOSの場合）
        if [[ "$OSTYPE" == "darwin"* ]]; then
            open mobile-access.html 2>/dev/null || true
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            xdg-open mobile-access.html 2>/dev/null || true
        fi

        # Web版QRコード
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}🔗 QRコード（Web版）:${NC}"
        echo "   https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$NGROK_URL"
        echo ""

        # 短縮URL生成サービスへのリンク（オプション）
        echo -e "${YELLOW}💡 ヒント:${NC}"
        echo "   URLが長い場合は、bit.lyやtinyurl.comで短縮できます"
        echo ""

    else
        echo -e "${RED}⚠️  公開URLの取得に失敗しました${NC}"
        echo "   http://localhost:4040 で確認してください"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}📊 管理画面:${NC}"
    echo "   • ngrok: http://localhost:4040"
    echo "   • ローカル: http://localhost:$PORT"
    echo ""
    echo -e "${RED}🛑 停止: Ctrl+C${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # シグナルハンドラー
    trap "kill $NEXTJS_PID $NGROK_PID 2>/dev/null; exit" INT TERM

    # プロセス待機
    wait $NEXTJS_PID
}

# メイン処理
main() {
    install_qr_tools
    cleanup
    setup_env
    start_app
}

main