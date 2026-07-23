# 引き継ぎドキュメント（Claude Code 向け）

このリポジトリの背景・設計判断・検証状況をまとめたものです。
**作業を始める前に必ず全体を読んでください。**
特に「4. 変更してはいけないもの」は、意図的に書いていない設定の一覧です。
親切心で追加すると環境が壊れます。

最終更新: 2026-07-23

---

## 1. 何を作っているか

### ユースケース

AIを使ったセミナーで、**参加者全員に同一の環境を提供**する。
オンボーディング時間を最短にし、すぐ触ってもらえる状態を作る。

### 前提条件（変更不可）

1. 全参加者は GitHub アカウントを保有している
2. RST のリポジトリは **Public**
3. リポジトリには AI オンボ用の初期ファイル（`AGENTS.md` など）が存在する
4. **API キーは RST が保有する**（参加者に個人のキーを発行させない）

### 追加要件

- 参加者それぞれの環境で動かす（共有環境ではない）
- **fork は必須ではない**（不要ならしない方がよい）
- API キーは**セミナー開催中のみ有効**。終了後に revoke する

### 達成した参加者フロー

```
1. リポジトリで Code → Codespaces → Create   （fork 不要）
2. ターミナルに1行貼る:
   bash scripts/setup-key.sh && source ~/.bashrc
3. npm run doctor  → 全部 OK なら claude で開始
```

参加者の操作は実質「Create を押す」＋「1行貼る」の2つだけ。

---

## 2. 重要な調査結果（再調査不要）

以下は調査済みの事実です。**これらを前提に設計されています。**

### 2-1. fork なしで Codespace を作れる

公開リポジトリからは fork せずに直接 Codespace を作成できる。
計算コストは**作成した本人の個人アカウント**に課金され、
GitHub Free の個人アカウントには月120コア時間・15GBの無料枠がある。

→ だから fork させない。操作が1つ減る。

### 2-2. GitHub のシークレット機能では API キーを配布できない

**これが設計の分岐点です。ここを誤解すると全部やり直しになります。**

- リポジトリ／Organization レベルの Codespaces シークレットは、
  **collaborator 権限を持つユーザーしか使用できない**
- 公開リポジトリの一般閲覧者は collaborator ではないので、注入されない
- fork にも渡らない
- これは仕様の欠陥ではなく**意図的な防御**
  （もし配布されたら、世界中の誰でもボタン一つでキーを取得できてしまう）

`devcontainer.json` の `secrets` プロパティ（recommended secrets）も
**値を配る機能ではない**。あれは「Codespace を作るユーザー自身が
自分のキーを入力する」ことを促すための宣言的メタデータにすぎない。

→ **キーを秘匿して配る方法は存在しない。**
→ 方針を「読まれても損害が出ない／即座に殺せる」に振った。

### 2-3. Claude Code は AGENTS.md を自動では読まない

Claude Code が自動読み込みするのは `CLAUDE.md` 系。
`AGENTS.md` は読まれない。

→ 本リポジトリでは `CLAUDE.md` から `@AGENTS.md` で import している。
→ **実体的な指示は `AGENTS.md` に書く。`CLAUDE.md` は import と最小限の記述のみ。**

### 2-4. Claude Code の VS Code 拡張はログインを要求する

拡張機能 `anthropic.claude-code` は、既定で Anthropic アカウントへの
サインインを促す。API キー運用のセミナーでは
「サインイン画面が出て参加者全員が止まる」事故になる。

→ **拡張は入れていない。CLI（`claude` コマンド）に統一している。**

### 2-5. 疎通確認は /v1/models を使う

`GET https://api.anthropic.com/v1/models` は**モデル名を指定せずに**
キーの有効性を確認できる（有効なら 200、無効なら 401）。

→ `doctor.sh` はこれを1段目に使う。モデル名変更で診断が壊れない。
→ 2段目のフォールバックとして `/v1/messages` も残してある。

---

## 3. キー運用モデル

**Anthropic Workspace のキルスイッチ方式**を採用。

| 守る対象 | 手段 |
|---------|------|
| 露出範囲 | 参加者のみ（口頭・画面・チャットで配布。**リポジトリには置かない**） |
| 金額 | Workspace のスペンド上限で頭打ちにする |
| 時間 | 終了後に Workspace をアーカイブ → **全キーが即座に無効化** |

セミナー専用の Workspace を作ることが必須。
アーカイブは取り消せないため、本番 Workspace と混ぜてはいけない。

`setup-key.sh` はキーを**コンテナ内のホームディレクトリにのみ**書き込む。
リポジトリには一切書かない。入力はエコーバックしない（画面共有中でも安全）。

---

## 4. 変更してはいけないもの

**以下は「書き忘れ」ではなく「意図的に書いていない」ものです。**
追加すると、参加者が環境構築の時点で詰まります。

| 対象 | 状態 | 追加してはいけない理由 |
|------|------|---------------------|
| `remoteUser` | **書かない** | イメージ既定のユーザーと不一致だと `$HOME` がずれ、キー設定が効かなくなる |
| `hostRequirements` | **書かない** | 無料枠のマシンで要求スペックを確保できず、起動が失敗しうる |
| devcontainer `features` | **使わない** | ビルド時間と失敗要因が増える |
| VS Code 拡張 `anthropic.claude-code` | **入れない** | ログインを要求して参加者が止まる（2-4 参照） |
| 外部 npm パッケージ | **追加しない** | 会場のネットワークで `npm install` が失敗すると全員止まる。現在ランタイム依存ゼロ |
| API キーのリポジトリ内配置 | **絶対禁止** | Public リポジトリ。Google Drive 経由も同様に禁止 |

### bootstrap.sh の設計制約

- **絶対に非ゼロ終了させない**（`exit 0` を維持すること）
  理由: `onCreateCommand` が失敗するとコンテナ生成ごと失敗する。
  多少不完全でもコンテナは生かし、`doctor.sh` に原因を伝えさせる方がよい。
- `set -e` を付けない（同上）
- `npm install` は3回リトライする（会場のネットワーク瞬断対策）
- PATH は3経路で通す（`~/.local/bin` リンク ／ rc 追記 ／ `npx` フォールバック）
- rc ファイルは `.bashrc` `.zshrc` `.profile` の**3つ全部**に書く
- rc への書き込みはマーカーで囲んで冪等にする（rebuild で重複しないこと）

---

## 5. ファイル構成

```
.devcontainer/
  devcontainer.json    コンテナ定義。onCreateCommand で bootstrap を呼ぶ
  bootstrap.sh         npm install + PATH 設定。常に exit 0
scripts/
  setup-key.sh         APIキーを rc に書き込む。リポジトリには書かない
  doctor.sh            環境診断。詰まったらまずこれ
src/
  server.js            HTTPサーバー（node:http のみ）
  store.js             タスクのインメモリ保管
  validate.js          入力バリデーション
test/
  store.test.js        7件、全パス
  validate.test.js     7件、うち1件が意図的に失敗
docs/
  exercises.md         参加者向け演習1〜4
  operator-guide.md    運営向け。事前準備・当日運用・キー失効手順
CLAUDE.md              @AGENTS.md を import するだけ
AGENTS.md              AI向けプロジェクト説明書（実体はこちら）
README.md              参加者向け。3ステップのセットアップ手順
```

### 意図的に失敗するテストがある

`test/validate.test.js` の「上限ちょうどの長さを受け付ける」は
**演習3の教材として、わざと失敗させています**（`src/validate.js` の
境界条件が `>=` になっている）。

**勝手に修正しないでください。** `npm test` が「13 pass / 1 fail」に
なるのが正常な状態です。

---

## 6. 検証状況

### 検証済み（サンドボックスの Linux + Node v22 で実行確認）

- `npm install` → `claude --version` が 2.1.217 を返す
- `npm install` を強制的に失敗させても bootstrap が exit 0 で完走し、案内が出る
- bootstrap / setup-key の冪等性（2回実行しても rc が重複しない）
- 参加者フロー（キー設定 → source → doctor）が通る
- `doctor.sh` が実 API に対して 401 を検出する
- サーバー: 正常JSON → 201、壊れたJSON → 400、不存在 → 404
- テスト: 14件中13パス、意図的な1件のみ失敗
- リポジトリ全体を走査し、キー文字列の混入ゼロ

### 未検証（Codespaces 上での実地確認が未実施）

**ここが唯一の残リスクです。**

- イメージ `mcr.microsoft.com/devcontainers/universal:2` が実際に引けるか
- Codespaces 上で `onCreateCommand` が期待通り動くか
- 実際の `$HOME` のパス
- `claude` の対話TUIが起動するか（`--version` しか確認していない）
- 有効なキーでの 200 応答（401 の経路しか確認していない）

落ちるとすれば**ほぼイメージタグ**です。他の指定を削ってあるため
切り分けは容易。落ちた場合の代替は `devcontainer.json` のコメントに記載:

- `mcr.microsoft.com/devcontainers/universal:linux`（ローリング最新）
- `mcr.microsoft.com/devcontainers/javascript-node:1-20`（軽量・Nodeのみ）

---

## 7. 次にやること

### 必須

1. **Codespace を実際に作って通しで検証する**
   （`docs/operator-guide.md` の「事前検証チェックリスト」を上から潰す）
2. **Prebuild を有効化する**
   Settings → Codespaces → Set up prebuild
   `onCreateCommand`（= `npm install`）が事前実行された状態で配布され、
   起動が数分 → 数十秒になる。**オンボ時間短縮に最も効く**
3. `README.md` 内のリンクを実際のリポジトリURLに合わせる

### 任意

- 演習1〜4を実際に通し、所要時間を実測して `docs/exercises.md` に反映
- 参加者人数に応じた Workspace のスペンド上限・レート上限の調整

### 将来的な拡張（現時点では不要）

参加者ごとに使用量を分けたい／個別に失効させたい要求が出た場合は、
**LLMプロキシ方式**（LiteLLM 等）への移行を検討する。

本物のキーはプロキシ側にのみ置き、参加者には TTL 付きの使い捨てトークンを配る。
Claude Code は `ANTHROPIC_BASE_URL` と `ANTHROPIC_AUTH_TOKEN` の
2つの環境変数で向き先と認証を差し替えられるため、
**教材側の変更はほぼ不要**（`setup-key.sh` に1行足す程度）。

引き換えにプロキシの運用コストが発生する。今回の規模では Workspace の
キルスイッチで足りるため、要求が出るまで着手しないこと。

---

## 8. 作業時の注意

- このファイルと `docs/operator-guide.md` は**公開リポジトリに含まれます**。
  キー・Workspace ID・請求情報などの機密は絶対に書かないでください。
- 設計判断を変更する場合は、このファイルの該当箇所も更新してください。
- 「4. 変更してはいけないもの」に手を入れる場合は、
  理由を明記したうえで、必ず Codespaces 上で実地検証してから反映すること。
