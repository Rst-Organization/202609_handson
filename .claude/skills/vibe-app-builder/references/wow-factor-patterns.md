# 「驚き」実装パターン集

短時間（30〜45分の実装ステップ内）でも組み込める、1枚のHTML/CSS/JSだけで完結する「わくわく感」の演出パターン集。外部ライブラリ・CDン・サーバーは使わない。1〜2個を選んで組み込む。詰め込みすぎない。

## 1. ボタンのマイクロインタラクション（一番手軽・迷ったらこれ）

ボタンにホバー・クリック時の反応をつけるだけで、体感の完成度が大きく上がる。

```css
button {
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
button:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 14px rgba(0,0,0,0.15);
}
button:active {
  transform: translateY(0);
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}
```

## 2. 結果のフェードイン・スライドイン

結果を表示する瞬間に動きをつけると「できた感」が出る。生成ボタンを押した時にクラスを付け替える。

```css
.reveal {
  animation: fadeInUp 0.4s ease both;
}
@keyframes fadeInUp {
  from { opacity: 0; transform: translateY(12px); }
  to   { opacity: 1; transform: translateY(0); }
}
```
```js
output.classList.remove("reveal");
void output.offsetWidth; // アニメーションを再生させるためのリフロー
output.classList.add("reveal");
```

## 3. 数字のカウントアップ演出

件数・金額・達成率などの数値を、0から目標値までアニメーションさせる。

```js
function countUp(el, target, duration = 600) {
  const start = performance.now();
  function tick(now) {
    const progress = Math.min((now - start) / duration, 1);
    el.textContent = Math.round(progress * target);
    if (progress < 1) requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);
}
// 使用例: countUp(document.getElementById("count"), 42);
```

## 4. 紙吹雪（confetti）風エフェクト

達成・完了時のお祝い演出。外部ライブラリなしで、divを動的に生成して降らせる簡易版。

```css
.confetti-piece {
  position: fixed;
  top: -10px;
  width: 8px;
  height: 8px;
  opacity: 0.9;
  border-radius: 2px;
  pointer-events: none;
  animation: fall 1.2s ease-in forwards;
}
@keyframes fall {
  to { transform: translateY(100vh) rotate(360deg); opacity: 0; }
}
```
```js
function celebrate() {
  const colors = ["#f87171", "#fbbf24", "#34d399", "#60a5fa", "#a78bfa"];
  for (let i = 0; i < 24; i++) {
    const piece = document.createElement("div");
    piece.className = "confetti-piece";
    piece.style.left = Math.random() * 100 + "vw";
    piece.style.background = colors[i % colors.length];
    piece.style.animationDelay = Math.random() * 0.3 + "s";
    document.body.appendChild(piece);
    setTimeout(() => piece.remove(), 1500);
  }
}
```

## 5. グラデーション背景・ガラスモーフィズム風カード

シックまたはポップな雰囲気を出したい時に。

```css
body {
  background: linear-gradient(135deg, #eef2ff, #fdf4ff);
}
.card {
  background: rgba(255,255,255,0.7);
  backdrop-filter: blur(8px);
  border: 1px solid rgba(255,255,255,0.4);
  border-radius: 16px;
}
```

## 6. 達成度・進捗メーター

チェックリスト系、集計系のアイデアと相性がよい。

```css
.meter-track { background: #e5e7eb; border-radius: 999px; height: 10px; overflow: hidden; }
.meter-fill { height: 100%; border-radius: 999px; transition: width 0.5s ease; }
```
```js
meterFill.style.width = `${percent}%`;
```

## 7. 絵文字リアクション

診断・生成結果に応じて絵文字を出し分けるだけで、一気に親しみやすくなる。

```js
function reactionEmoji(score) {
  if (score >= 80) return "🎉";
  if (score >= 50) return "😊";
  return "💪";
}
```

## 8. ダークモード切り替え

時間に余裕がある時のオプション。CSS変数とdata属性の切り替えだけで実装できる。

```css
:root { --bg: #ffffff; --text: #1f2430; }
[data-theme="dark"] { --bg: #1a1d24; --text: #f5f6f8; }
body { background: var(--bg); color: var(--text); transition: background 0.2s, color 0.2s; }
```
```js
toggleBtn.addEventListener("click", () => {
  document.documentElement.dataset.theme =
    document.documentElement.dataset.theme === "dark" ? "" : "dark";
});
```

## 9. タイピングエフェクト

生成された文章を1文字ずつ表示すると、「AIが今書いている感」が出て体験として面白い（実際はテンプレートの表示速度を演出しているだけでよい）。

```js
function typeText(el, text, speed = 15) {
  el.textContent = "";
  let i = 0;
  const timer = setInterval(() => {
    el.textContent += text[i];
    i++;
    if (i >= text.length) clearInterval(timer);
  }, speed);
}
```

## 選び方の目安

| ヒアリング結果 | おすすめパターン |
|---|---|
| ポップで楽しい雰囲気 | 1（ボタン反応）＋ 4（紙吹雪）または 7（絵文字） |
| きちんと系・シック系 | 1（ボタン反応）＋ 2（フェードイン）＋ 5（グラデーション/ガラス風） |
| 集計・診断系のアイデア | 3（カウントアップ）または 6（達成度メーター） |
| 文章生成系のアイデア | 2（フェードイン）＋ 9（タイピングエフェクト） |
| 特にこだわりなし | 1（ボタン反応）＋ 2（フェードイン）だけで十分 |
