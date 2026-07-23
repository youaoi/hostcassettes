#!/bin/bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
ARCHS="${ARCHS:-arm64}"
CONFIGURATION="${CONFIGURATION:-Release}"
CREATE_DMG="${CREATE_DMG:-0}"

destination_args=()
if [[ "$ARCHS" != *" "* ]]; then
	destination_args=(-destination "platform=macOS,arch=$ARCHS")
fi

mkdir -p "$DIST_DIR"

CONFIGURATION="$CONFIGURATION" ARCHS="$ARCHS" "$ROOT_DIR/build.sh"

build_settings=$(xcodebuild -project "$ROOT_DIR/Host Cassettes.xcodeproj" -scheme "Host Cassettes" -configuration "$CONFIGURATION" "${destination_args[@]}" ARCHS="$ARCHS" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO -showBuildSettings)
built_products_dir=$(printf '%s\n' "$build_settings" | awk -F ' = ' '/BUILT_PRODUCTS_DIR = / { print $2; exit }')
full_product_name=$(printf '%s\n' "$build_settings" | awk -F ' = ' '/FULL_PRODUCT_NAME = / { print $2; exit }')
app_path="$built_products_dir/$full_product_name"
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT_DIR/Info.plist")
archive_base="host_cassettes_${version}_${ARCHS// /-}"

NOTARIZE="${NOTARIZE:-0}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
ENTITLEMENTS="$ROOT_DIR/HostCassettes.entitlements"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-notarytool-profile}"

# コード署名（Hardened Runtime を有効化）
# 公証は内側から順に署名する必要がある
if [[ "$SIGN_IDENTITY" == "-" ]]; then
	# アドホック署名（テスト用）
	codesign --force --deep --sign - "$app_path"
else
	LAUNCHER_ENTITLEMENTS="$ROOT_DIR/Launcher.entitlements"
	LAUNCHER_APP="$app_path/Contents/Resources/Launcher.app"

	# 1. Launcher.app を先に署名（Hardened Runtime + secure timestamp）
	if [[ -d "$LAUNCHER_APP" ]]; then
		codesign --force --options runtime \
			--timestamp \
			--entitlements "$LAUNCHER_ENTITLEMENTS" \
			--sign "$SIGN_IDENTITY" \
			"$LAUNCHER_APP"
	fi

	# 2. メインアプリを署名（--deep は残りの内包バイナリに適用）
	codesign --force --deep --options runtime \
		--timestamp \
		--entitlements "$ENTITLEMENTS" \
		--sign "$SIGN_IDENTITY" \
		"$app_path"
fi

ditto -c -k --sequesterRsrc --keepParent "$app_path" "$DIST_DIR/${archive_base}.zip"

# 公証（NOTARIZE=1 の場合のみ実行）
if [[ "$NOTARIZE" == "1" ]]; then
	echo "Submitting for notarization..."
	xcrun notarytool submit "$DIST_DIR/${archive_base}.zip" \
		--keychain-profile "$NOTARYTOOL_PROFILE" \
		--wait

	echo "Stapling notarization ticket..."
	xcrun stapler staple "$app_path"

	# staple 済みの app で zip を再生成
	rm "$DIST_DIR/${archive_base}.zip"
	ditto -c -k --sequesterRsrc --keepParent "$app_path" "$DIST_DIR/${archive_base}.zip"
fi

if [[ "$CREATE_DMG" == "1" ]]; then
	VOLUME_NAME="Host Cassettes $version" \
	APP_PATH="$app_path" \
	OUTPUT_DIR="$DIST_DIR" \
	DMG_STEM="$archive_base" \
	DMG_NAME="${archive_base}.dmg" \
	"$ROOT_DIR/Release/create-dmg.sh"

	if [[ "$NOTARIZE" == "1" ]]; then
		echo "Stapling notarization ticket to dmg..."
		xcrun stapler staple "$DIST_DIR/${archive_base}.dmg"
	fi
fi

echo "Created release assets in $DIST_DIR"