#!/bin/bash
# アプリケーションを停止
pkill -f "node.*next" 2>/dev/null || true
echo "✅ QuickCall LiveKit を停止しました"