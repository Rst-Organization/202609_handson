#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Claude Code の初回セットアップをやり直す
#
# 用途: 初回起動の質問で違う方を選んでしまい、
#       ログイン画面が出る / モデルが選べない などで詰まったとき。
#
# 消すのは ~/.claude.json（初回セットアップの記録）だけ。
#   - APIキーは ~/.bashrc にあるので消えない
#   - このセミナー用のモデル指定（.claude/settings.json）にも影響しない
#     → リポジトリ側の設定なので、ホーム側を消しても変わらない
# -----------------------------------------------------------------------------
set -uo pipefail

echo ""
echo "======================================================"
echo " Claude Code の初回セットアップをやり直します"
echo "======================================================"
echo ""

if [ -f "$HOME/.claude.json" ]; then
  rm -f "$HOME/.claude.json"
  echo " [OK] 初回セットアップの記録を消しました。"
else
  echo " [OK] 初回セットアップの記録はもともとありません。"
fi

# 起動中の claude が残っていると、終了時に設定を書き戻して元に戻ってしまう
if pgrep -x claude >/dev/null 2>&1; then
  echo ""
  echo " [注意] claude がまだ動いています。"
  echo "        起動中のターミナルで Ctrl+C を2回押して終了してから、"
  echo "        もう一度このコマンドを実行してください。"
fi

echo ""
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo " [注意] APIキーが今のターミナルに読み込まれていません。"
  echo ""
  echo " 次の順番で実行してください:"
  echo ""
  echo "   source ~/.bashrc"
  echo "   claude"
  echo ""
  echo " それでも 'APIキー 未設定' と言われる場合は、キーの設定からやり直してください:"
  echo ""
  echo "   bash scripts/setup-key.sh && source ~/.bashrc"
  echo ""
else
  echo " APIキーは設定されたままです。次を実行してください:"
  echo ""
  echo "   claude"
  echo ""
  echo " 最初の質問からやり直しになります。"
  echo " README.md の「ステップ4」を見ながら選んでください。"
  echo ""
fi
echo "======================================================"
echo ""

exit 0
