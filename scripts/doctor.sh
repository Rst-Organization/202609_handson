#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 環境の健全性チェック。詰まったら まずこれを実行する。
#
# API疎通は 2段構えで確認する:
#   1段目: GET /v1/models    … モデル名に依存しないためこちらを優先
#   2段目: POST /v1/messages … 1段目で判定できなかった場合のみ
# こうすることで「モデル名が変わって診断が誤検知する」事故を防ぐ。
# -----------------------------------------------------------------------------
set -uo pipefail

OK=" [ OK ] "
NG=" [ NG ] "
PROBLEMS=0

# 2段目で使うモデル。必要なら環境変数 RST_DOCTOR_MODEL で差し替え可能。
FALLBACK_MODEL="${RST_DOCTOR_MODEL:-claude-haiku-4-5-20251001}"

echo ""
echo "======================================================"
echo " RST AI セミナー — 環境チェック"
echo "======================================================"
echo ""

# --- 1. Node.js -------------------------------------------------------------
if command -v node >/dev/null 2>&1; then
  NODE_VER="$(node --version)"
  NODE_MAJOR="$(echo "$NODE_VER" | sed 's/^v\([0-9]*\).*/\1/')"
  if [ "${NODE_MAJOR:-0}" -ge 18 ] 2>/dev/null; then
    echo "${OK}Node.js $NODE_VER"
  else
    echo "${NG}Node.js $NODE_VER (18以上が必要)"
    PROBLEMS=$((PROBLEMS + 1))
  fi
else
  echo "${NG}Node.js が見つかりません"
  PROBLEMS=$((PROBLEMS + 1))
fi

# --- 2. 依存関係 ------------------------------------------------------------
if [ -d "./node_modules" ]; then
  echo "${OK}依存関係 インストール済み"
else
  echo "${NG}node_modules がありません"
  echo "        → npm install を実行してください"
  PROBLEMS=$((PROBLEMS + 1))
fi

# --- 3. Claude Code ---------------------------------------------------------
if command -v claude >/dev/null 2>&1; then
  echo "${OK}Claude Code 実行可能 ($(claude --version 2>/dev/null | head -1))"
elif [ -e "./node_modules/.bin/claude" ]; then
  echo "${NG}Claude Code は入っていますが PATH が通っていません"
  echo "        → source ~/.bashrc を実行してください"
  echo "        → それでも駄目なら 'npx claude' で起動できます"
  PROBLEMS=$((PROBLEMS + 1))
else
  echo "${NG}Claude Code が未インストールです"
  echo "        → npm install を実行してください"
  PROBLEMS=$((PROBLEMS + 1))
fi

# --- 4. APIキーと疎通 -------------------------------------------------------
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "${NG}APIキー 未設定"
  echo "        → bash scripts/setup-key.sh && source ~/.bashrc"
  PROBLEMS=$((PROBLEMS + 1))
else
  MASKED="${ANTHROPIC_API_KEY:0:11}...${ANTHROPIC_API_KEY: -4}"
  echo "${OK}APIキー 設定済み ($MASKED)"

  if ! command -v curl >/dev/null 2>&1; then
    echo "${NG}curl が無いため疎通確認をスキップしました"
  else
    # ---- 1段目: モデル一覧（モデル名に依存しない） ----
    CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
      https://api.anthropic.com/v1/models \
      -H "x-api-key: ${ANTHROPIC_API_KEY}" \
      -H "anthropic-version: 2023-06-01" 2>/dev/null)"

    # ---- 2段目: 1段目で判定不能なら実際にメッセージを投げる ----
    if [ "$CODE" != "200" ] && [ "$CODE" != "401" ] && [ "$CODE" != "403" ] && [ "$CODE" != "429" ]; then
      CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
        https://api.anthropic.com/v1/messages \
        -H "x-api-key: ${ANTHROPIC_API_KEY}" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "{\"model\":\"${FALLBACK_MODEL}\",\"max_tokens\":4,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}" \
        2>/dev/null)"
    fi

    case "$CODE" in
      200)
        echo "${OK}API疎通 成功"
        ;;
      401 | 403)
        echo "${NG}API疎通 失敗: キーが無効か失効しています (HTTP $CODE)"
        echo "        → 貼り付けミスの可能性があります。setup-key.sh をやり直してください"
        echo "        → 直らない場合は運営に申し出てください"
        PROBLEMS=$((PROBLEMS + 1))
        ;;
      429)
        echo "${NG}API疎通 失敗: レート制限中 (HTTP 429)"
        echo "        → 少し待ってから再実行してください"
        PROBLEMS=$((PROBLEMS + 1))
        ;;
      400 | 404)
        echo "${NG}API疎通 失敗: リクエストが受理されませんでした (HTTP $CODE)"
        echo "        → 運営へ: モデル '${FALLBACK_MODEL}' が利用可能か確認してください"
        echo "        → RST_DOCTOR_MODEL 環境変数で差し替えられます"
        PROBLEMS=$((PROBLEMS + 1))
        ;;
      000 | "")
        echo "${NG}API疎通 失敗: ネットワークに到達できません"
        echo "        → 会場のネットワーク接続を確認してください"
        PROBLEMS=$((PROBLEMS + 1))
        ;;
      *)
        echo "${NG}API疎通 失敗 (HTTP $CODE)"
        PROBLEMS=$((PROBLEMS + 1))
        ;;
    esac
  fi
fi

echo ""
echo "------------------------------------------------------"
if [ "$PROBLEMS" -eq 0 ]; then
  echo " すべて正常です。'claude' と入力して開始してください。"
  echo " このあとの進め方は README.md の「ステップ4」からです。"
else
  echo " ${PROBLEMS}件の問題があります。上記の → の指示に従ってください。"
  echo " 解決しない場合は運営に声をかけてください。"
fi
echo "======================================================"
echo ""

exit 0
