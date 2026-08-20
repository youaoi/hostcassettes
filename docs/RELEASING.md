# Releasing Host Cassettes

この fork は GitHub Releases を配布の基準にし、Sparkle による自動アップデートを GitHub Pages 経由で配信します。

## 事前確認

1. `README.md` のバッジとダウンロード案内が fork を向いていることを確認する。
2. `Info.plist` のバージョンを更新する。
   - `CFBundleShortVersionString`: マーケティングバージョン（例: `0.8.8`）。機能追加・バグ修正でユーザーに見せたい番号を変更する。
   - `CFBundleVersion`: ビルド番号（整数、例: `5`）。**リリースごとに必ずインクリメント**する。Sparkle はこの値で更新を検知する。**絶対に減らしてはいけない**（マーケティングバージョンをリセットしても継続してカウントアップする）。現在の最大値は `5`（0.9.2-arm64.2 で設定）。
3. `./build.sh` と `xcodebuild test -project "Host Cassettes.xcodeproj" -scheme "Host Cassettes" -destination "platform=macOS" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` が通ることを確認する。
4. リリースノートを `docs/release-notes/` に用意する。

## ローカルで配布物を作る

arm64 の zip を作る:

```bash
CONFIGURATION=Release ARCHS=arm64 ./package-release.sh
```

arm64 の zip と dmg を作る:

```bash
CONFIGURATION=Release ARCHS=arm64 CREATE_DMG=1 ./package-release.sh
```

生成物は `dist/` に出力されます。

## GitHub Releases へ公開する

1. 変更を `master` に入れる。
2. 例のようにタグを作る。

```bash
git tag v0.8.7-arm64.1
git push origin v0.8.7-arm64.1
```

1. `.github/workflows/release.yml` が draft release を作成し、zip を添付する。
2. draft release に `docs/release-notes/0.8.7-arm64.1.md` の内容を貼る。
3. 必要なら手元で作った dmg を追加添付して公開する。

## 今後 Sparkle を有効化するとき

Sparkle 自動更新は有効化済みです。

- **appcast URL**: `https://youaoi.github.io/hostcassettes/appcast.xml`
- **EdDSA 公開鍵**: `Info.plist` の `SUPublicEDKey` に設定済み
- **秘密鍵**: Keychain に保存済み。CI 用に `SPARKLE_EDDSA_KEY` GitHub Secret に登録が必要

### GitHub Secret の設定

リポジトリの Settings → Secrets and variables → Actions に以下を登録する:

| Secret 名                   | 値                                                                             |
| --------------------------- | ------------------------------------------------------------------------------ |
| `SPARKLE_EDDSA_KEY`         | `generate_keys -x` でエクスポートした秘密鍵の内容                              |
| `DEVELOPER_ID_P12_BASE64`   | Developer ID Application 証明書 + 秘密鍵を p12 で書き出し base64 encode した値 |
| `DEVELOPER_ID_P12_PASSWORD` | 上記 p12 のパスワード                                                          |

`DEVELOPER_ID_P12_BASE64` が未設定の場合、CI はアドホック署名でビルドし警告を出します。ローカルで Developer ID 署名・公証したバイナリを GitHub Release に上書きアップロードしてください。

### GitHub Pages の設定

リポジトリの Settings → Pages で Source を **Deploy from a branch**、Branch を **gh-pages** / `/ (root)` に設定する。

### 仕組み

1. タグ push で `release.yml` が起動する。
2. CI がビルド → zip を EdDSA 署名 → `appcast.xml` を生成する。
3. `appcast.xml` を gh-pages ブランチにデプロイする。
4. GitHub Release を draft で作成する。
5. Sparkle が `appcast.xml` をポーリングし、ユーザに更新を通知する。
