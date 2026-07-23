# 公証（Notarization）セットアップ手順

別の Mac で公証付きリリースを行う際のセットアップ手順です。

## 前提条件

- Apple Developer Program に加入済み（Team ID: `A25KY8P552`）
- Xcode がインストール済み

---

## 1. Developer ID Application 証明書の取得

### 1-1. CSR を作成する

1. **キーチェーンアクセス** を起動
2. メニュー → **キーチェーンアクセス** → **証明書アシスタント** → **認証局に証明書を要求...**
3. 以下を入力：
   - メールアドレス：Apple ID のメール（例: `ja01youki@gmail.com`）
   - 通称：任意（例: `Yuki AOI`）
   - CA のメールアドレス：同じメールアドレスを入力（または空白）
   - **「ディスクに保存」** を選択
4. `CertificateSigningRequest.certSigningRequest` を保存

### 1-2. Developer Portal で証明書を発行する

1. [developer.apple.com/account/resources/certificates/add](https://developer.apple.com/account/resources/certificates/add) を開く
2. **Developer ID Application** を選択 → Continue
3. **G2 Sub-CA (Xcode 11.4.1 or later)** を選択 → Continue
4. 上で作成した `.certSigningRequest` をアップロード → Continue
5. **Download** ボタンで `developerID_application.cer` をダウンロード
6. ダウンロードした `.cer` をダブルクリック → キーチェーンに追加

### 1-3. インストール確認

```bash
security find-identity -v -p codesigning | grep "Developer ID"
# → "Developer ID Application: Yuki AOI (A25KY8P552)" が表示されること
```

---

## 2. App-Specific Password の生成

1. [appleid.apple.com](https://appleid.apple.com) にサインイン
2. **サインインとセキュリティ** → **App 用パスワード** → **＋**
3. ラベルに `notarytool` と入力 → 作成
4. 表示された16桁パスワード（`xxxx-xxxx-xxxx-xxxx` 形式）をコピーして保存

---

## 3. notarytool の認証情報をキーチェーンに登録

```bash
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "ja01youki@gmail.com" \
  --team-id A25KY8P552 \
  --password "xxxx-xxxx-xxxx-xxxx"
```

`Credentials saved to Keychain.` と表示されれば成功。

---

## 4. 公証付きパッケージの作成

```bash
CONFIGURATION=Release ARCHS=arm64 NOTARIZE=1 \
  SIGN_IDENTITY="Developer ID Application: Yuki AOI (A25KY8P552)" \
  ./package-release.sh
```

出力に以下が表示されれば成功：

```
status: Accepted
Stapling notarization ticket...
Created release assets in dist/
```

### 公証なし（テスト用アドホック署名）

```bash
CONFIGURATION=Release ARCHS=arm64 ./package-release.sh
```

---

## 5. 署名・公証の確認

```bash
APP="dist/Host Cassettes.app"

# 署名確認
codesign --verify --deep --verbose=2 "$APP"

# Gatekeeper 評価（"accepted" が出ること）
spctl --assess --verbose "$APP"

# 公証 Staple 確認
xcrun stapler validate "$APP"
```

---

## トラブルシューティング

### `Invalid` で公証が失敗する場合

詳細ログを確認する（`<submission-id>` は notarytool の出力から取得）：

```bash
xcrun notarytool log <submission-id> --keychain-profile "notarytool-profile"
```

よくある原因：

| エラーメッセージ                                           | 対処                                            |
| ---------------------------------------------------------- | ----------------------------------------------- |
| The signature of the binary is invalid.                    | 内包 app（Launcher.app 等）を個別に先に署名する |
| The signature does not include a secure timestamp.         | `--timestamp` フラグを追加する                  |
| The executable does not have the hardened runtime enabled. | `--options runtime` フラグを追加する            |

### 証明書がキーチェーンに表示されない

CSR を作成した Mac と**同じ Mac**で `.cer` をインポートする必要があります。
別の Mac で CSR を作成した場合は秘密鍵が紐付かないため、CSR を作り直してください。

---

## 関連ファイル

| ファイル                     | 説明                                            |
| ---------------------------- | ----------------------------------------------- |
| `HostCassettes.entitlements` | メインアプリの Hardened Runtime 用 entitlements |
| `Launcher.entitlements`      | Launcher.app 用 entitlements                    |
| `package-release.sh`         | 署名・公証・zip 生成スクリプト                  |
