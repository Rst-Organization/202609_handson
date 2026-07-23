#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# RST AIセミナー: APIキー設定
#
# 重要な設計方針:
#   - キーはこのリポジトリには一切書き込まない
#   - 書き込み先はコンテナ内のホームディレクトリのみ（Git管理外・破棄される）
#   - 入力はエコーバックしない（画面共有・録画中でも漏れない）
# -----------------------------------------------------------------------------
set -uo pipefail

MARK_START="# >>> rst-seminar key >>>"
MARK_END="# <<< rst-seminar key <<<"

echo ""
echo "======================================================"
echo " RST AI セミナー — APIキー設定"
echo "======================================================"
echo ""
echo " 会場で共有されたキーを貼り付けて Enter を押してください。"
echo " (セキュリティのため、入力内容は画面に表示されません)"
echo ""
printf " ANTHROPIC_API_KEY: "
read -rs KEY
echo ""

if [ -z "${KEY:-}" ]; then
  echo ""
  echo " [エラー] 入力が空です。もう一度実行してください。" >&2
  exit 1
fi

# 前後の空白・改行を除去（コピペ事故の最頻出パターン）
KEY="$(printf '%s' "$KEY" | tr -d '[:space:]')"

case "$KEY" in
  sk-ant-*) ;;
  *)
    echo ""
    echo " [警告] キーが 'sk-ant-' で始まっていません。"
    echo "        貼り付けミスの可能性がありますが、このまま続行します。"
    ;;
esac

# --- 各シェルの rc ファイルに書き込む（冪等：何度実行しても重複しない） -----
write_key_block() {
  local rc="$1"
  [ -e "$rc" ] || touch "$rc" 2>/dev/null || return 0
  [ -w "$rc" ] || return 0

  if grep -qF "$MARK_START" "$rc" 2>/dev/null; then
    sed -i "\|$MARK_START|,\|$MARK_END|d" "$rc" 2>/dev/null || return 0
  fi

  {
    echo "$MARK_START"
    echo "export ANTHROPIC_API_KEY='$KEY'"
    echo "$MARK_END"
  } >> "$rc"

  chmod 600 "$rc" 2>/dev/null || true
}

for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  write_key_block "$rc"
done

echo ""
echo " [OK] 設定を保存しました。"
echo ""
echo " 現在のターミナルに反映するには、次を実行してください:"
echo ""
echo "   source ~/.bashrc"
echo ""
echo " その後の疎通確認:"
echo ""
echo "   npm run doctor"
echo ""
echo "======================================================"
echo ""
