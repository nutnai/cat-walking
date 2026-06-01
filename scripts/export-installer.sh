#!/bin/zsh

set -euo pipefail

repo_root=${0:A:h:h}
build_dir="$repo_root/.build/arm64-apple-macosx/release"
dist_dir="$repo_root/dist"
app_name="CatWalking"
plist_source="$repo_root/packaging/Info.plist"
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$plist_source")
safe_version=${version//[^A-Za-z0-9._-]/-}
versioned_name="$app_name-$safe_version"
app_bundle="$dist_dir/${app_name}.app"
pkg_path="$dist_dir/${versioned_name}-Installer.pkg"
temp_dir=$(mktemp -d "$repo_root/.build/export-installer.XXXXXX")
install_root="$temp_dir/root"
install_app_bundle="$install_root/Applications/${app_name}.app"
contents_dir="$install_app_bundle/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"
dist_contents_dir="$app_bundle/Contents"
dist_macos_dir="$dist_contents_dir/MacOS"
dist_resources_dir="$dist_contents_dir/Resources"

cleanup() {
  rm -rf "$temp_dir"
}
trap cleanup EXIT

echo "Building release binary..."
cd "$repo_root"
swift build -c release

echo "Preparing app bundle..."
rm -rf "$app_bundle"
mkdir -p "$macos_dir" "$resources_dir" "$dist_macos_dir" "$dist_resources_dir"

cp "$build_dir/$app_name" "$macos_dir/$app_name"
cp -R "$build_dir/${app_name}_${app_name}.bundle" "$resources_dir/"
cp "$plist_source" "$contents_dir/Info.plist"

cp "$build_dir/$app_name" "$dist_macos_dir/$app_name"
cp -R "$build_dir/${app_name}_${app_name}.bundle" "$dist_resources_dir/"
cp "$plist_source" "$dist_contents_dir/Info.plist"

chmod +x "$macos_dir/$app_name"
chmod +x "$dist_macos_dir/$app_name"

echo "Creating installer package..."
rm -f "$pkg_path"
pkgbuild \
  --root "$install_root" \
  --identifier com.nutnai.catwalking \
  --version "$version" \
  --install-location / \
  "$pkg_path"

echo "Export complete:"
echo "  Version: $version"
echo "  App: $app_bundle"
echo "  Pkg: $pkg_path"