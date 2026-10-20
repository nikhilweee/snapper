#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

universal=false
if [[ "${1:-}" == "--universal" ]]; then
    universal=true
    shift
    set -- --arch arm64 --arch x86_64 "$@"
fi

swift build -c release --product Snapper "$@"
bin_dir="$(swift build -c release --show-bin-path "$@")"
if [[ "$universal" == true ]]; then
    architectures="$(/usr/bin/lipo -archs "$bin_dir/Snapper")"
    if [[ " $architectures " != *" arm64 "* || " $architectures " != *" x86_64 "* ]]; then
        printf 'Universal build is missing a required architecture: %s\n' "$architectures" >&2
        exit 1
    fi
fi
mkdir -p build
stage_dir="$(mktemp -d "$PWD/build/.Snapper.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
staged_app="$stage_dir/Snapper.app"
app_dir="$PWD/build/Snapper.app"
mkdir -p "$staged_app/Contents/MacOS" "$staged_app/Contents/Resources"
cp "$bin_dir/Snapper" "$staged_app/Contents/MacOS/Snapper"
cp Resources/Info.plist "$staged_app/Contents/Info.plist"
cp Resources/AppIcon.icns "$staged_app/Contents/Resources/AppIcon.icns"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Resources/Info.plist)"
/usr/bin/plutil -lint "$staged_app/Contents/Info.plist"
/usr/bin/codesign --force --options runtime --sign - --identifier "$bundle_id" "$staged_app"
/usr/bin/codesign --verify --strict "$staged_app"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$staged_app" "$stage_dir/Snapper.zip"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
checksum="$(/usr/bin/shasum -a 256 "$stage_dir/Snapper.zip" | cut -d ' ' -f 1)"
sed -e "s/@VERSION@/$version/g" -e "s/@SHA256@/$checksum/g" \
    Casks/snapper.rb.in > "$stage_dir/snapper.rb"
# Replace the previous generated outputs only after packaging and signing succeed.
rm -rf "$app_dir"
mv "$staged_app" "$app_dir"
mv "$stage_dir/Snapper.zip" "$PWD/build/Snapper.zip"
mv "$stage_dir/snapper.rb" "$PWD/build/snapper.rb"
printf 'Built %s and build/Snapper.zip\n' "$app_dir"
/usr/bin/shasum -a 256 build/Snapper.zip
printf 'Matching Homebrew cask: build/snapper.rb\n'
