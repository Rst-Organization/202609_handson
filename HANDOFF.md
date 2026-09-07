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

### 2-6. Claude Code は Node.js 22 以上を要求する（2026-07-23 追記）

`@anthropic-ai/claude-code`（検証時 2.1.218）は `engines.node >= 22` を要求する。
Node 20 の環境では `npm install` 時に **EBADENGINE 警告**が出る
（インストール自体は通り `claude --version` も動くが、将来のバージョンで
ハード失敗する余地が残る）。

→ devcontainer の `image` を、当初の `universal:2`（既定 Node が 20）から
  **Node 22 を確定的に積む** `mcr.microsoft.com/devcontainers/javascript-node:1-22` に変更した。
→ `universal:2` の tag 自体は有効・pull 可能（後述 6 のローカル検証で確認済み）。
  不採用の理由は Node バージョンのみ。
→ イメージを差し替える場合も **Node 22 未満には落とさないこと**。

### 2-7. Codespaces で HTML をプレビューする手段（2026-09-07 追記）

**Live Server 系の VS Code 拡張は使えない。** 調査で確定した事実:

- `ritwickdey.LiveServer` は**構造的に動かない**。ブラウザ起動に npm の `opn` を
  直接呼んでおり（`src/appModel.ts`）、`vscode.env.asExternalUri` を一切使っていない。
  拡張はコンテナ側で動くため `xdg-open` を叩くだけで、参加者のブラウザには何も起きない。
  `http://127.0.0.1:5500` が `https://<codespace>-5500.app.github.dev` に変換されない。
  （Issue #1054 / #2740 / #1375。最終更新も 2022→2026 で3年半空いている）
- Microsoft 公式 `ms-vscode.live-server` は `asExternalUri` を使うので転送自体は正しいが、
  **埋め込みプレビュー（iframe）が Codespaces の private ポートで 401 になる**。
  GitHub 認証のリダイレクトが iframe 内で完結できないため（Issue #111、2021年から Open）。
- 同じ理由で `portsAttributes` の `onAutoForward: "openPreview"`（VS Code 内蔵ブラウザ）
  も避ける。**実ブラウザのタブ = トップレベル遷移なら認証が通る**ので `notify` を使い、
  参加者に通知の「ブラウザーで開く」を押させる。

→ **拡張を足さず、`preview.py`（標準ライブラリのみ）でサーバーを立てる方式を採用した。**
  拡張を増やさないので、HANDOFF 4 の「ビルド失敗要因を増やさない」方針とも整合する。

**`python3` はイメージに存在する**（実測: `docker run mcr.microsoft.com/devcontainers/javascript-node:1-22
python3 --version` → `Python 3.11.2`）。ただし `python`（無印）と `pip` は**無い**ので、
必ず `python3` と書くこと。なお python3 は base の `node:22-bookworm` からの推移的依存
（`mercurial` 経由）で入っており、`bookworm-slim` 系には無い。
**イメージを slim 系に変えると `preview.py` が動かなくなる。**

ポート自動転送は言語非依存（VS Code 本体の `remoteExplorer.ts` がプロセスと
ターミナル出力の両方を監視する）。`preview.py` が起動時に
`http://localhost:3000/` を print しているのは、この出力ベース検知に確実に乗せるため。
**この print 行を消さないこと。**

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
| VS Code 拡張 `ritwickdey.LiveServer` | **入れない** | Codespaces で構造的に動かない（2-7 参照） |
| VS Code 拡張 `ms-vscode.live-server` | **入れない** | 埋め込みプレビューが Codespaces で 401 になる（2-7 参照） |
| `portsAttributes.3000.onAutoForward` | **`notify` を維持** | `silent` だと通知が出ずプレビューに気づけない。`openPreview` は iframe 認証で 401（2-7 参照） |
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
  reset-claude.sh      claude 初回セットアップのやり直し（~/.claude.json を削除）
preview.py             apps/ を 3000 番で配信。標準ライブラリのみ
apps/                  参加者の成果物（HTML）の置き場所
.claude/
  settings.json        モデル固定（sonnet）と権限
  skills/
    work-idea-hearing/     ステップ5: ヒアリング → アイデア提案
    vibe-app-builder/      ステップ6: 見た目ヒアリング → 実装
src/                   【旧トラック】タスク管理API。現行の流れでは使わない
test/                  【旧トラック】うち1件が意図的に失敗
docs/
  exercises.md         【旧トラック】エンジニア向け演習1〜4。README からは外した
  operator-guide.md    運営向け。事前準備・当日運用・キー失効手順
CLAUDE.md              @AGENTS.md を import するだけ
AGENTS.md              AI向けプロジェクト説明書（実体はこちら）
README.md              参加者向け。準備〜ステップ8まで全部
```

### 現行のセミナーの流れ（2026-09-07 時点）

**skills を使う流れが本線。** `src/` のタスク管理API 演習は旧トラック。

```
ステップ1〜4  準備（Codespace 作成 → キー設定 → doctor → claude 初回起動）
ステップ5     /work-idea-hearing   ヒアリング → アイデア3〜5個 → 1つ選ぶ
ステップ6     /vibe-app-builder    見た目ヒアリング → apps/ に HTML を実装
ステップ7     python3 preview.py   自分のブラウザで動作確認
ステップ8     見せあいっこ
```

README ではこれを「現場の要件定義プロセス（ヒアリング→要件定義→設計→実装→動作確認）を
AIと分担してやる体験」としてフレーミングしている。運営はこの説明を
Codespace 起動待ちの1〜3分で話す想定。

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

### 追加検証済み（2026-07-23 ローカル Docker 実行）

`javascript-node:1-22`（Node 22）および `node:20` の実コンテナで通し確認済み:

- `.devcontainer/bootstrap.sh` が **exit 0** で完走し `claude 2.1.218` を導入
- claude が PATH に乗る（3経路）／ PATH ブロックが3つの rc に永続化
- `setup-key.sh` の冪等性（2回実行しても `ANTHROPIC_API_KEY` 行は1つのまま）
- `doctor.sh` が **実 API に対して HTTP 401 を検出**（401 経路を実機確認）
- `npm test` が 13 pass / 1 fail、サーバーが 201 / 400 / 404
- `universal:2` と `javascript-node:1-22` の **イメージタグが pull 可能**（`docker manifest inspect`）
- Node 20 では EBADENGINE 警告、Node 22 では警告消滅 → イメージを Node 22 系に変更（2-6）

### 未検証（実 Codespaces 上でのみ確認可能）

- Codespaces のエージェントが `onCreateCommand` を期待どおり呼ぶか（ローカルでは手動実行で確認済み）
- Prebuild 有効時の挙動
- `claude` 対話TUIの起動（`--version` までは確認）
- **有効なキーでの 200 応答**（本物のセミナーキーが要る。運営が事前チェックで確認：operator-guide 4）

> 実 Codespaces 検証には `gh` の `codespace` スコープが必要だが、Org の OAuth アプリ制限で
> 未取得（`gh auth refresh -s codespace` が反映されない）。スコープ取得後に `gh codespace` で通せる。
> それまでは上記のローカル検証＋運営の実キー事前チェックで代替する。

落ちた場合の代替イメージ（**Node 22 未満に落とさないこと**）:

- `mcr.microsoft.com/devcontainers/javascript-node:22`（同等・タグ違い）
- `mcr.microsoft.com/devcontainers/typescript-node:1-22`（同等＋TypeScript同梱）

---

## 7. 次にやること

### 必須

1. **Codespace を実際に作って通しで検証する**
   （ローカル Docker では検証済み＝上記 6 を参照。実 Codespaces は `gh` の codespace
   スコープ取得後、または運営が手動で `docs/operator-guide.md` の
   「事前検証チェックリスト」を上から潰す）
2. **Prebuild を有効化する**
   Settings → Codespaces → Set up prebuild
   `onCreateCommand`（= `npm install`）が事前実行された状態で配布され、
   起動が数分 → 数十秒になる。**オンボ時間短縮に最も効く**
3. `README.md` 内のリンクを実際のリポジトリURLに合わせる
4. **`claude` 初回起動の質問文言を実機で確認し、README ステップ4の表を差し替える**
   現在の表は「何を聞かれるか・どちらを選ぶか・間違えた時の症状」で書いてあり、
   文言が変わっても壊れないようにはしてあるが、**英語原文は未確認**。
   claude CLI がネイティブバイナリ配布になっておりローカルから文字列を抽出できなかった。
   → 検証 Codespace で実際に `claude` を初回起動し、**各画面のスクリーンショットを撮って
     README に貼る**のが最も親切。質問の順番もそこで確定させること。
5. **`preview.py` を実 Codespaces で通す**
   ローカル Docker では python3 の存在と `http.server` の動作を確認済みだが、
   「3000 番が転送されて右下に通知が出る → ブラウザーで開くで実際に見える」までは
   実 Codespaces でのみ確認できる。**ここが落ちるとステップ7が全滅する。**

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
