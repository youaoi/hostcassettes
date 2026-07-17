#!/bin/bash
set -euo pipefail

project="Host Cassettes.xcodeproj"
scheme="Host Cassettes"
archs="${ARCHS:-arm64}"
configuration="${CONFIGURATION:-Debug}"

build_args=(
	-project "$project"
	-scheme "$scheme"
	-configuration "$configuration"
)

if [[ "$archs" != *" "* ]]; then
	build_args+=(
		-destination "platform=macOS,arch=$archs"
	)
fi

build_args+=(
	ARCHS="$archs"
	CODE_SIGN_IDENTITY=""
	CODE_SIGNING_REQUIRED=NO
	CODE_SIGNING_ALLOWED=NO
)

xcodebuild "${build_args[@]}"

build_settings=$(xcodebuild "${build_args[@]}" -showBuildSettings)
built_products_dir=$(printf '%s\n' "$build_settings" | awk -F ' = ' '/BUILT_PRODUCTS_DIR = / { print $2; exit }')
full_product_name=$(printf '%s\n' "$build_settings" | awk -F ' = ' '/FULL_PRODUCT_NAME = / { print $2; exit }')
app_path="$built_products_dir/$full_product_name"

find "$app_path" -type f | while read -r path; do
	if file "$path" | grep -q 'Mach-O universal binary'; then
		mode=$(stat -f '%Lp' "$path")
		tmp_path="$path.arm64"
		lipo "$path" -thin arm64 -output "$tmp_path"
		chmod "$mode" "$tmp_path"
		mv "$tmp_path" "$path"
	fi
done
