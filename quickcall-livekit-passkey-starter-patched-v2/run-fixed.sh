#!/bin/bash
echo "🎥 QuickCall LiveKit - ビデオ通話アプリケーション"
echo "📱 ブラウザで開く: http://localhost:3000"
echo ""
echo "使い方："
echo "1. http://localhost:3000 にアクセス"
echo "2. ルームIDを入力または生成"
echo "3. 「Join」をクリックして通話開始"
echo ""
echo "停止: Ctrl+C"
echo ""

# 開発モードで起動（ビルドエラーを回避）
npm run dev
