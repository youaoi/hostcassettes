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

codesign --force --deep --sign - "$app_path"

ditto -c -k --sequesterRsrc --keepParent "$app_path" "$DIST_DIR/${archive_base}.zip"

if [[ "$CREATE_DMG" == "1" ]]; then
	VOLUME_NAME="Host Cassettes $version" \
	APP_PATH="$app_path" \
	OUTPUT_DIR="$DIST_DIR" \
	DMG_STEM="$archive_base" \
	DMG_NAME="${archive_base}.dmg" \
	"$ROOT_DIR/Release/create-dmg.sh"
fi

echo "Created release assets in $DIST_DIR"