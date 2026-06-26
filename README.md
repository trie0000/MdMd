# MdMd — オフライン PWA 版 Markdown エディタ

完全にオフラインで動作するブラウザベースの Markdown エディタです。
インストール後は **一切の外部通信を行いません**(CDN ゼロ、解析ツールゼロ、
テレメトリゼロ)。全アセットを `vendor/` 配下にローカル同梱し、Service Worker
でプリキャッシュしています。

## 機能

- `.md` / `.markdown` ファイルの編集
- markdown-it + DOMPurify + highlight.js によるライブプレビュー
- CodeMirror 5 によるエディタ(Markdown / GFM モード)
- タブ、ダークモード、フォントサイズ、スクロール同期
- 表示モード切替: エディタのみ / プレビューのみ / 両方表示
  (ツールバー / View メニュー / `Ctrl+1` `Ctrl+2` `Ctrl+3`)
- **`Ctrl+S` で元ファイルを上書き保存**
  (File System Access API 経由。OS がダブルクリックで PWA を呼んだ
  ときに書き込み権限が自動付与されます)

## Windows へのインストール(初回のみ・30 秒程度)

必要環境: Microsoft Edge(Chromium ベース、バージョン 102 以降)。

1. このフォルダ全体を任意の場所にコピー(例: `C:\Tools\mdeditor`)
2. `install.cmd` をダブルクリック
   - PowerShell の小さなウィンドウが開き、
     `127.0.0.1:17645` でローカル HTTP サーバが起動します
     (ループバックのみ・LAN には公開されません)
   - 自動的に Edge が起動します
3. Edge のアドレスバー右端にある **インストールアイコン** をクリック
   (もしくは `…` メニュー → 「アプリ」 → 「このサイトをアプリとしてインストール」)
4. インストール完了後、Edge が
   *「.md、.markdown を MdMd で開きますか?」* と尋ねるので
   **「許可」** を選択
5. PowerShell ウィンドウを閉じる。インストーラはもう不要です

これで Windows 側で MdMd が `.md / .markdown` のハンドラとして
登録されます。エクスプローラで `.md` をダブルクリックすると
MdMd で開きます。

## 使い方

- **ファイルを開く**: エクスプローラからダブルクリック / ウィンドウへ
  ドラッグ&ドロップ / `Ctrl+O`
- **保存(上書き)**: `Ctrl+S`。ダブルクリックで開いたファイルは
  そのまま元の場所へ上書きされます。D&D で開いたタブは初回保存時に
  「名前を付けて保存」ダイアログが出ます
- **新規タブ**: `Ctrl+N`
- **タブを閉じる**: `Ctrl+W`
- **表示モード切替**: `Ctrl+1`(エディタのみ) / `Ctrl+2`(プレビューのみ) /
  `Ctrl+3`(両方表示)

## ネットワーク挙動

| シーン | 外部通信 |
|------|------------------|
| `install.cmd` 実行中 | 無し。127.0.0.1 のみ Listen |
| Edge での初回読み込み | 無し。Service Worker が全アセットをループバックサーバからプリキャッシュ |
| インストール後の毎回(ダブルクリック起動など) | **無し**。Edge は SW キャッシュから配信 |
| Service Worker の fetch ハンドラ | 同一オリジンのみ処理。クロスオリジンは仕組み上発生しません(このビルドには外部参照がそもそも無いため) |

Edge の DevTools → Network で確認できます。何も外に出ていません。

## ファイル構成

```
mdeditor/
├── index.html              # エントリポイント(vendor のみ参照)
├── app.js                  # esbuild で事前ビルドした UI
├── styles.css              # アプリスタイル
├── manifest.json           # PWA マニフェスト(file_handlers で md/markdown/txt 登録)
├── sw.js                   # Service Worker(プリキャッシュ専用)
├── install.cmd             # ワンショット PWA インストーラ起点
├── install.ps1             # install.cmd が呼ぶループバック HTTP サーバ
├── install-help.html       # 関連付けトラブル解決ガイド(単独 HTML)
├── icons/                  # PWA アイコン(192 / 512 / maskable)
└── vendor/                 # サードパーティライブラリ + フォントのオフラインコピー
    ├── react.production.min.js          (MIT)
    ├── react-dom.production.min.js      (MIT)
    ├── codemirror/                      (MIT)
    ├── markdown-it.min.js               (MIT)
    ├── purify.min.js                    (Apache-2.0 / MPL-2.0)
    ├── highlight/                       (BSD-3-Clause)
    └── fonts/                           (SIL OFL-1.1: Inter, JetBrains Mono)
```

## 同梱ライブラリのライセンス

同梱している全ライブラリは商用利用可です。

| ライブラリ | ライセンス |
|---------|---------|
| React 18 / ReactDOM 18 | MIT |
| CodeMirror 5.65 | MIT |
| markdown-it 14 | MIT |
| DOMPurify 3 | Apache-2.0 OR MPL-2.0 |
| highlight.js 11 | BSD-3-Clause |
| Inter (フォント) | SIL OFL-1.1 |
| JetBrains Mono (フォント) | SIL OFL-1.1 |

## 配布手順(オフライン環境 / 制限ネットワーク向け)

`github.com` や CDN へ到達できないマシンでも MdMd は動かせます。
インターネットに繋がるマシンで配布物を準備し、手段を問わずターゲットへ
持ち込み、`install.cmd` を一度実行する流れです。

### A. 配布物を準備する(インターネット可のマシンで)

```bash
git clone https://github.com/trie0000/MdMd.git mdeditor
cd mdeditor
# (任意) JSX を改造した場合は app.js を再ビルド。
# 詳細は下の「開発者向け: アップデート手順」を参照
```

リポジトリには必要なライブラリ・フォントすべてが同梱済みなので、
通常の配布なら `npm install` 等は不要です。

### B. パッケージング

受け取り側の環境に応じて形態を選びます。

| 形態 | 適するケース |
|------|----------|
| ZIP アーカイブ | USB / メール添付 / SharePoint / ファイル共有 |
| ターゲット上で `git clone` | ターゲットが GitHub には到達可能なケース |
| 社内 Git ミラー | GitLab / Azure DevOps 等の内部ミラー経由で配布したいケース |
| ネットワーク共有 (`\\server\share\mdeditor\`) | 同一イントラ内で複数ユーザが導入するケース |

ZIP の例(親ディレクトリで):

```bash
zip -r mdeditor-vX.Y.zip mdeditor \
    -x 'mdeditor/.git/*' 'mdeditor/.github/*' 'mdeditor/.DS_Store' \
       'mdeditor/design_handoff_mdeditor/*'
```

成果物は約 1.2 MB です。

### C. 引き渡し

受け取り側のポリシーで認可された経路を使います。

- 承認済み USB メモリ
- IT 部門が認可するファイル転送ポータル
- IT 部門が事前に置く管理対象ネットワーク共有
- 内部パッケージ管理(社内 Chocolatey リポジトリ、Intune Win32 アプリ等)

### D. Windows 機ごとのインストール

各エンドユーザ(または IT 部門による集中展開)で:

1. `mdeditor/` を任意の場所に展開(例: `C:\Tools\mdeditor\`)
2. `install.cmd` をダブルクリック
3. Edge のタブが開いたら、アドレスバーの **インストールアイコン** をクリック
   → **インストール**
4. Edge が `.md` / `.markdown` の関連付け確認を出したら
   **「許可」** を選択
5. PowerShell ウィンドウを閉じる。完了

インストールアイコンが出ない、または `.md` が他のアプリで開いてしまう
場合は [install-help.html](install-help.html) を参照してください。

### E. 集中展開(任意)

SCCM / Intune / グループポリシー等で複数台に展開する場合の指針:

- 展開フォルダはマシン共通パス配下に置く
  (例: `C:\Program Files\MdMd\`)
- 各ユーザのログオンスクリプト / 1 回だけのスケジュールタスクから
  `install.cmd` を実行。PWA インストールは Edge のユーザごと処理です
- DISM の `defaultAppAssociations.xml` で関連付けを事前定義することも
  可能ですが、PWA の progID は Edge のインストール時に生成されるため、
  `install.cmd` に任せるほうが簡単です

### F. インストール済みの更新

インストーラは **固定ポート `17645`** で待ち受けます。これは Edge から
見た PWA の一意識別子の一部なので、ポートを変えなければ Service Worker は
同じオリジンを認識でき、`edge://apps` に重複エントリを作らずにアセットを
更新できます。

更新フロー:

1. フォルダを最新版に置き換え(`git pull` か ZIP 上書き)
2. 新版には `sw.js` の `CACHE_VERSION` が bump 済み
3. `install.cmd` を実行
4. Edge がインストーラタブを開いたら、**`edge://apps` / スタートメニュー /
   既存の MdMd ウィンドウ** いずれかで MdMd を起動。これで稼働中の PWA
   が自オリジンへ繋いで新しい Service Worker を取得できます
5. PWA 内で <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd>。
   新 SW が activate し、新アセットが配信されます
6. `install.cmd` のコンソールウィンドウを閉じる。完了

通常の更新ではアンインストール → 再インストールは不要です。同じオリジン上で
ファイルが差し替わるだけです。

#### ランダムポート時代のバージョンからの移行

固定ポート化以前のビルドはランダムポートで起動していたため、
`install.cmd` を実行するたび別 PWA として登録されてしまっていました。
`edge://apps` に MdMd の重複エントリが複数ある場合:

1. `edge://apps` を開く
2. **MdMd のエントリを全部アンインストール**
3. 新しい `install.cmd` を実行。今後は 1 件だけ登録されます

#### 強制的に再インストールしたい場合

メジャーリリースや SW が刺さってしまった時など:

1. `edge://apps` → MdMd → **アンインストール**
2. `install.cmd` を実行 → 新規インストール
3. `.md` / `.markdown` の関連付け確認に再度「許可」

#### ポート番号を変えたい場合

`17645` が他ツールと衝突する場合は別ポートを指定できます。ただし
**毎回同じ値を使う** こと(PWA 識別子の安定性確保のため)。

```cmd
install.cmd -Port 18000
```

ポートを変えると Edge から見た origin が変わる = 新規インストール扱いに
なるので、`edge://apps` から古いエントリを先に消してください。

## 開発者向け: アップデート手順

ビルドのソースは [`app.src.js`](app.src.js) です(esbuild が prettify した
`React.createElement` 形式)。`app.js` はこれを minify した出力なので、
**手で `app.js` を編集しないこと**。

vendor 配下のライブラリを差し替えるとき:

1. `vendor/` 配下に新バージョンを上書きダウンロード
2. ロジックを変えたい場合は `app.src.js` を編集して再ビルド:

   ```bash
   npx esbuild app.src.js --minify --target=es2020 --outfile=app.js
   ```

3. **`sw.js` の `CACHE_VERSION` を bump** すること。これを忘れると
   古い Service Worker が古いアセットを返し続けます
4. PWA を再インストール(または Edge の SW ページで「更新」をクリック)

## 自動保存(クラッシュ復旧)

タブの内容・タイトル・dirty フラグは編集のたびに 500ms 遅延で
`localStorage` に保存され、ページ非表示・離脱・PC 強制終了が起きても
復旧できます:

| 保存先 | 保存内容 |
|---|---|
| `localStorage` (`mdmd-session`) | タブ一覧(本文 / 名前 / dirty / 元パス) + アクティブタブ id |
| `IndexedDB` (`mdmd` / `h`) | `FileSystemFileHandle` — 復元後も `Ctrl+S` が元ファイルに直接書ける |

復旧のしくみ:

1. 起動時、`localStorage` にセッションがあればサンプルではなくそれを復元
2. その直後に IndexedDB からファイルハンドルを非同期で読み込み、
   タブ id が一致するものを再アタッチ
3. ファイルハンドルの権限が失効しているケース(ファイル削除・移動など)では
   `Ctrl+S` が自然に「名前を付けて保存」へフォールバック

セッションを意図的にクリアしたいとき(まっさらな状態から始めたい等):

```js
// 開発者ツールのコンソールで
__mdmd_clearSession();
location.reload();
```

## 制限事項

- Edge / Chrome 102 以上が必要(File Handling API と `launchQueue` 利用のため)。
  Firefox / Safari ではダブルクリック起動フローは動きません
- グループポリシーで PWA インストールやファイル関連付け変更が
  禁止されている場合、インストール手順がブロックされる可能性があります。
  必要に応じて IT 部門へ確認してください
- `install.cmd` 実行中の `127.0.0.1` Listen が EDR 製品で警告される
  可能性があります(ループバックのみ・ワンショットの待受です)
