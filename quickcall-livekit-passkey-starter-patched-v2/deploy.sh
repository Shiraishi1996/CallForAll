#!/bin/bash

# =====================================================
# QuickCall LiveKit Passkey Starter - デプロイスクリプト
# =====================================================

set -e  # エラーがあった場合は処理を停止

# カラー出力用の設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ロゴ表示
echo -e "${GREEN}"
echo "====================================="
echo "  QuickCall LiveKit Deploy Script"
echo "====================================="
echo -e "${NC}"

# デプロイプラットフォームの選択
echo -e "${YELLOW}デプロイプラットフォームを選択してください:${NC}"
echo "1) Vercel"
echo "2) Railway"
echo "3) Render"
echo "4) Docker (ローカル/VPS)"
echo "5) カスタムVPS (PM2使用)"
read -p "選択 (1-5): " platform

# 環境変数のチェック
check_env_vars() {
    echo -e "${YELLOW}環境変数をチェック中...${NC}"

    required_vars=(
        "LIVEKIT_URL"
        "LIVEKIT_API_KEY"
        "LIVEKIT_API_SECRET"
        "NEXT_PUBLIC_LIVEKIT_URL"
        "WEBAUTHN_RP_ID"
        "WEBAUTHN_ORIGIN"
        "WEBAUTHN_RP_NAME"
        "SESSION_SECRET"
        "DATABASE_URL"
    )

    missing_vars=()

    if [ ! -f .env.production ]; then
        echo -e "${RED}.env.production ファイルが見つかりません${NC}"
        echo "作成しますか? (y/n)"
        read create_env
        if [ "$create_env" = "y" ]; then
            create_env_file
        else
            echo -e "${RED}デプロイを中止します${NC}"
            exit 1
        fi
    fi

    # .env.productionから環境変数を読み込み
    set -a
    source .env.production
    set +a

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        echo -e "${RED}以下の環境変数が設定されていません:${NC}"
        printf '%s\n' "${missing_vars[@]}"
        echo -e "${YELLOW}.env.production ファイルを編集してください${NC}"
        exit 1
    fi

    echo -e "${GREEN}環境変数のチェック完了✓${NC}"
}

# 環境変数ファイルの作成
create_env_file() {
    echo -e "${YELLOW}.env.production ファイルを作成中...${NC}"

    cat > .env.production << 'EOF'
# LiveKit Cloud
# LiveKitのダッシュボードから取得: https://cloud.livekit.io
LIVEKIT_URL=wss://YOUR-LIVEKIT-URL
LIVEKIT_API_KEY=YOUR_API_KEY
LIVEKIT_API_SECRET=YOUR_API_SECRET
NEXT_PUBLIC_LIVEKIT_URL=wss://YOUR-LIVEKIT-URL

# WebAuthn (Passkey)
# 本番環境のドメインに変更してください
WEBAUTHN_RP_ID=yourdomain.com
WEBAUTHN_ORIGIN=https://yourdomain.com
WEBAUTHN_RP_NAME=QuickCall

# App session (JWT signing secret)
# ランダムな文字列に変更してください
SESSION_SECRET=CHANGE_ME_TO_A_LONG_RANDOM_STRING_$(openssl rand -hex 32)

# Prisma Database
# SQLite (開発用)
DATABASE_URL="file:./prisma/prod.db"

# PostgreSQL (本番推奨) - コメントアウトを外して使用
# DATABASE_URL="postgresql://username:password@host:port/database?schema=public"

# MySQL (代替) - コメントアウトを外して使用
# DATABASE_URL="mysql://username:password@host:port/database"
EOF

    echo -e "${GREEN}.env.production ファイルを作成しました${NC}"
    echo -e "${YELLOW}必ず編集してから続行してください${NC}"
    read -p "編集が完了したらEnterキーを押してください..."
}

# 依存関係のインストール
install_dependencies() {
    echo -e "${YELLOW}依存関係をインストール中...${NC}"
    npm ci --production=false
    echo -e "${GREEN}依存関係のインストール完了✓${NC}"
}

# Prismaのセットアップ
setup_prisma() {
    echo -e "${YELLOW}Prismaをセットアップ中...${NC}"
    npx prisma generate
    npx prisma migrate deploy
    echo -e "${GREEN}Prismaのセットアップ完了✓${NC}"
}

# ビルド処理
build_project() {
    echo -e "${YELLOW}プロジェクトをビルド中...${NC}"
    npm run build
    echo -e "${GREEN}ビルド完了✓${NC}"
}

# Vercelへのデプロイ
deploy_vercel() {
    echo -e "${YELLOW}Vercelへデプロイ中...${NC}"

    # Vercel CLIのチェック
    if ! command -v vercel &> /dev/null; then
        echo "Vercel CLIをインストール中..."
        npm i -g vercel
    fi

    # vercel.json の作成
    cat > vercel.json << 'EOF'
{
  "framework": "nextjs",
  "buildCommand": "prisma generate && next build",
  "env": {
    "DATABASE_URL": "@database_url",
    "LIVEKIT_URL": "@livekit_url",
    "LIVEKIT_API_KEY": "@livekit_api_key",
    "LIVEKIT_API_SECRET": "@livekit_api_secret",
    "NEXT_PUBLIC_LIVEKIT_URL": "@next_public_livekit_url",
    "WEBAUTHN_RP_ID": "@webauthn_rp_id",
    "WEBAUTHN_ORIGIN": "@webauthn_origin",
    "WEBAUTHN_RP_NAME": "@webauthn_rp_name",
    "SESSION_SECRET": "@session_secret"
  }
}
EOF

    # デプロイ実行
    vercel --prod

    echo -e "${GREEN}Vercelへのデプロイ完了✓${NC}"
}

# Railwayへのデプロイ
deploy_railway() {
    echo -e "${YELLOW}Railwayへデプロイ中...${NC}"

    # Railway CLIのチェック
    if ! command -v railway &> /dev/null; then
        echo "Railway CLIをインストールしてください:"
        echo "https://docs.railway.app/develop/cli"
        exit 1
    fi

    # railway.toml の作成
    cat > railway.toml << 'EOF'
[build]
builder = "NIXPACKS"
buildCommand = "npm ci && prisma generate && npm run build"

[deploy]
startCommand = "npx prisma migrate deploy && npm run start"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3
EOF

    # デプロイ実行
    railway login
    railway link
    railway up

    echo -e "${GREEN}Railwayへのデプロイ完了✓${NC}"
}

# Renderへのデプロイ
deploy_render() {
    echo -e "${YELLOW}Renderへデプロイ中...${NC}"

    # render.yaml の作成
    cat > render.yaml << 'EOF'
services:
  - type: web
    name: quickcall-livekit
    env: node
    buildCommand: npm ci && npx prisma generate && npm run build
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
        sync: false
      - key: SESSION_SECRET
        sync: false
EOF

    echo -e "${GREEN}render.yaml を作成しました${NC}"
    echo "Renderダッシュボードでこのリポジトリを接続してください"
    echo "https://dashboard.render.com/new/web"
}

# Dockerデプロイ
deploy_docker() {
    echo -e "${YELLOW}Docker用の設定を作成中...${NC}"

    # Dockerfile の作成
    cat > Dockerfile << 'EOF'
FROM node:18-alpine AS base

# Dependencies stage
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY package.json package-lock.json ./
COPY prisma ./prisma/
RUN npm ci

# Builder stage
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN npx prisma generate
RUN npm run build

# Runner stage
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder /app/prisma ./prisma

USER nextjs

EXPOSE 3000
ENV PORT 3000

CMD ["sh", "-c", "npx prisma migrate deploy && node server.js"]
EOF

    # docker-compose.yml の作成
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    env_file:
      - .env.production
    volumes:
      - ./prisma:/app/prisma
    restart: unless-stopped

  # PostgreSQL (オプション)
  # postgres:
  #   image: postgres:15
  #   environment:
  #     POSTGRES_DB: quickcall
  #     POSTGRES_USER: postgres
  #     POSTGRES_PASSWORD: postgres
  #   volumes:
  #     - postgres_data:/var/lib/postgresql/data
  #   ports:
  #     - "5432:5432"

volumes:
  postgres_data:
EOF

    echo -e "${GREEN}Docker設定ファイルを作成しました${NC}"
    echo -e "${YELLOW}Dockerでビルド・起動するには:${NC}"
    echo "docker-compose up -d --build"
}

# PM2デプロイ (VPS)
deploy_pm2() {
    echo -e "${YELLOW}PM2用の設定を作成中...${NC}"

    # ecosystem.config.js の作成
    cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'quickcall-livekit',
    script: 'npm',
    args: 'start',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
};
EOF

    # デプロイスクリプト
    cat > deploy-pm2.sh << 'EOF'
#!/bin/bash

# PM2のインストール確認
if ! command -v pm2 &> /dev/null; then
    echo "PM2をインストール中..."
    npm install -g pm2
fi

# ログディレクトリ作成
mkdir -p logs

# 環境変数の読み込み
set -a
source .env.production
set +a

# Prismaのセットアップ
npx prisma generate
npx prisma migrate deploy

# ビルド
npm run build

# PM2でアプリケーションを起動
pm2 stop quickcall-livekit || true
pm2 delete quickcall-livekit || true
pm2 start ecosystem.config.js --env production

# PM2の自動起動設定
pm2 startup
pm2 save

echo "デプロイ完了！"
echo "アプリケーションステータス: pm2 status"
echo "ログ確認: pm2 logs quickcall-livekit"
EOF

    chmod +x deploy-pm2.sh

    echo -e "${GREEN}PM2設定ファイルを作成しました${NC}"
    echo -e "${YELLOW}VPSでデプロイするには:${NC}"
    echo "./deploy-pm2.sh"
}

# Nginxの設定例を生成
create_nginx_config() {
    cat > nginx.conf.example << 'EOF'
server {
    listen 80;
    server_name yourdomain.com;

    # HTTPSへリダイレクト
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    # SSL証明書 (Let's Encryptを使用する場合)
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # セキュリティヘッダー
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

    echo -e "${GREEN}nginx.conf.example を作成しました${NC}"
}

# メイン処理
main() {
    echo -e "${YELLOW}デプロイの準備を開始します...${NC}"

    # 環境変数チェック
    check_env_vars

    # 依存関係のインストール
    install_dependencies

    # Prismaセットアップ
    setup_prisma

    # ビルド
    build_project

    # プラットフォーム別デプロイ
    case $platform in
        1)
            deploy_vercel
            ;;
        2)
            deploy_railway
            ;;
        3)
            deploy_render
            ;;
        4)
            deploy_docker
            ;;
        5)
            deploy_pm2
            create_nginx_config
            ;;
        *)
            echo -e "${RED}無効な選択です${NC}"
            exit 1
            ;;
    esac

    echo -e "${GREEN}"
    echo "====================================="
    echo "  デプロイ設定が完了しました！"
    echo "====================================="
    echo -e "${NC}"

    # 追加情報の表示
    echo -e "${YELLOW}次のステップ:${NC}"
    echo "1. 環境変数を本番環境用に設定"
    echo "2. LiveKit Cloudでプロジェクトを作成"
    echo "3. データベースを設定（PostgreSQL推奨）"
    echo "4. カスタムドメインを設定"
    echo ""
    echo -e "${GREEN}詳細なドキュメント:${NC}"
    echo "https://github.com/Shiraishi1996/CallForAll"
}

# スクリプトの実行
main