#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# コンテナ生成時に自動実行される（devcontainer.json の onCreateCommand）。
#
# 設計方針:
#   - 絶対に非ゼロで終了しない。ここで失敗してもコンテナは使える状態にする。
#     （受講生が「環境が作れない」状態になるのが最悪のケースなので、
#       多少不完全でもコンテナは生かし、doctor.sh で原因を伝える）
#   - npm install はリトライする（会場のネットワーク瞬断対策）
#   - PATH は複数の経路で通す（どれか一つ効けばよい）
# -----------------------------------------------------------------------------
set -uo pipefail   # -e はあえて付けない（途中で死なせない）

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR" || exit 0

BIN_DIR="$PROJECT_DIR/node_modules/.bin"
LOCAL_BIN="$HOME/.local/bin"
MARK_START="# >>> rst-seminar path >>>"
MARK_END="# <<< rst-seminar path <<<"

log() { echo "[bootstrap] $*"; }

log "作業ディレクトリ: $PROJECT_DIR"
log "HOME: $HOME"
log "Node: $(node --version 2>/dev/null || echo '見つかりません')"

# --- 1. 依存関係のインストール（最大3回リトライ） ---------------------------
INSTALL_OK=0
for attempt in 1 2 3; do
  log "npm install 実行中... (試行 ${attempt}/3)"
  if npm install --no-audit --no-fund; then
    INSTALL_OK=1
    break
  fi
  log "失敗しました。5秒後に再試行します。"
  sleep 5
done

if [ "$INSTALL_OK" -ne 1 ]; then
  log "警告: npm install が3回とも失敗しました。"
  log "      コンテナは起動しますが、ターミナルで手動実行してください: npm install"
fi

# --- 2. claude を PATH に通す（3経路） --------------------------------------
# 経路A: ~/.local/bin へのシンボリックリンク（多くの環境で既にPATH上）
mkdir -p "$LOCAL_BIN" 2>/dev/null || true
if [ -e "$BIN_DIR/claude" ]; then
  ln -sf "$BIN_DIR/claude" "$LOCAL_BIN/claude" 2>/dev/null \
    && log "リンク作成: $LOCAL_BIN/claude"
fi

# 経路B: 各シェルの rc ファイルに PATH を追記（冪等）
add_path_block() {
  local rc="$1"
  [ -e "$rc" ] || touch "$rc" 2>/dev/null || return 0
  [ -w "$rc" ] || return 0

  if grep -qF "$MARK_START" "$rc" 2>/dev/null; then
    sed -i "\|$MARK_START|,\|$MARK_END|d" "$rc" 2>/dev/null || return 0
  fi

  {
    echo "$MARK_START"
    echo "export PATH=\"$LOCAL_BIN:$BIN_DIR:\$PATH\""
    echo "$MARK_END"
  } >> "$rc"

  log "PATH設定を追記: $rc"
}

for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  add_path_block "$rc"
done

# 経路C: npx（上記が全滅でも `npx claude` は動く）

# --- 3. 動作確認 -------------------------------------------------------------
export PATH="$LOCAL_BIN:$BIN_DIR:$PATH"
CLAUDE_VER="$(claude --version 2>/dev/null | head -1)"

echo ""
echo "======================================================"
echo " RST AI セミナー環境 — セットアップ完了"
echo "======================================================"
echo ""
if [ -n "$CLAUDE_VER" ]; then
  echo "  Claude Code: $CLAUDE_VER"
else
  echo "  Claude Code: 未確認（ターミナルで npm install を実行してください）"
fi
echo ""
echo "  次にやること — 下の1行をターミナルに貼り付けてください:"
echo ""
echo "    bash scripts/setup-key.sh && source ~/.bashrc"
echo ""
echo "  その後 'claude' で起動します。演習は docs/exercises.md。"
echo ""
echo "======================================================"
echo ""

# 何があっても成功扱いで終える
exit 0
