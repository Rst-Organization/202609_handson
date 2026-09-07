#!/usr/bin/env python3
"""作ったアプリを、自分のブラウザで開くための簡易サーバー。

    python3 preview.py

Codespaces は「クラウド上のコンテナ」の中で動いている。
そのため、できあがった HTML ファイルをエディタ上でダブルクリックしても
自分のパソコンのブラウザでは開けない（コンテナの中と外は別世界のため）。

このスクリプトでコンテナの中にサーバーを立てると、
Codespaces がポートを自動で外に転送してくれるので、
右下に出る通知の「ブラウザーで開く」から手元のブラウザで見られるようになる。

止めるときは Ctrl+C。
"""

import http.server
import os
import socketserver
import sys
from pathlib import Path

# 3000 は .devcontainer/devcontainer.json の forwardPorts に登録済み。
# 登録済みのポートは Codespaces が確実に転送してくれるので、ここを変えないこと。
PORT = int(os.environ.get("PORT", "3000"))
ROOT = Path(__file__).resolve().parent / "apps"


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self):
        # HTML を直してリロードしたら即反映されてほしいので、キャッシュさせない
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("  %s\n" % (fmt % args))


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    pages = sorted(p.name for p in ROOT.glob("*.html"))

    socketserver.TCPServer.allow_reuse_address = True
    try:
        httpd = socketserver.TCPServer(("0.0.0.0", PORT), Handler)
    except OSError:
        print("")
        print(f"  [エラー] ポート {PORT} は既に使われています。")
        print("  すでに別のターミナルで preview.py が動いていないか確認してください。")
        print("  動いていれば、そちらのタブに戻れば大丈夫です。")
        print("  止めたい場合は、そのターミナルで Ctrl+C を押してください。")
        print("")
        return 1

    print("")
    print("======================================================")
    print(" アプリのプレビュー")
    print("======================================================")
    print("")
    # ↓ この localhost の URL を出力することで、Codespaces がポートを検知して
    #   「ブラウザーで開く」の通知を出してくれる。この行を消さないこと。
    print(f"  http://localhost:{PORT}/")
    print("")
    if pages:
        print("  公開中のファイル:")
        for name in pages:
            print(f"    - {name}")
    else:
        print("  apps/ にまだ HTML がありません。")
        print("  Claude に作ってもらってから、このページを再読み込みしてください。")
    print("")
    print("  画面の右下に出る通知の「ブラウザーで開く」を押してください。")
    print("  通知が消えてしまったら、下の「ポート」タブから 3000 番の")
    print("  地球儀のアイコンを押しても開けます。")
    print("")
    print("  終わるときは Ctrl+C")
    print("======================================================")
    print("")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("")
        print("  プレビューを終了しました。")
        print("")
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
