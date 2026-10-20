# Releasing Snapper

Snapper follows Relarm and Timely's SwiftPM/AppKit structure, `com.nikhilweee.*` bundle namespace, universal ZIP releases on GitHub, and distribution through `nikhilweee/homebrew-tap`. The app and ZIP stay in the ignored `build/` directory.

## Signing

All builds and releases use free ad hoc signing. No Apple Developer membership, certificate, signing credentials, or notarization service is required. The build script verifies the signature before replacing the previous outputs. GitHub Actions needs only its automatically provided `GITHUB_TOKEN` to publish the release.

Downloaded releases are not notarized. The generated cask preserves quarantine metadata, so users may need to approve the first launch in System Settings → Privacy & Security → Open Anyway. See [Apple's instructions for opening apps](https://support.apple.com/en-us/102445). Accessibility permission is a separate requirement.

## Build and publish

1. Set the version and build number in `Resources/Info.plist`. The version is the single source for both the release tag check and generated cask. Source is published under [MIT](../LICENSE), as in Relarm and Timely.
2. Run `swift test`, `./build.sh --universal`, and the [manual acceptance checklist](manual-testing.md). Check both Intel and Apple Silicon, including the oldest supported macOS version (14).
3. Commit and push the release changes to `nikhilweee/snapper`, tag the commit `v<version>`, and push that tag. `.github/workflows/release.yml` checks the tag against the plist, runs tests, builds both architectures, and publishes `Snapper.zip` and `snapper.rb` as GitHub Release assets.
4. Download `snapper.rb` from that published release, review it, and copy it into `Casks/snapper.rb` in `nikhilweee/homebrew-tap`. Commit and push the tap change. Use the **published** cask: a local ZIP has a different checksum from CI's ZIP.
5. Test `brew install --cask nikhilweee/tap/snapper`, launch `/Applications/Snapper.app`, approve the app if prompted, grant Accessibility access, and check a Shift-drag. Also check an upgrade and uninstall. Only `--zap` should remove user configuration.

`Casks/snapper.rb.in` is the source template. `build.sh` fills in the version and exact ZIP checksum to produce `build/snapper.rb`. There is no placeholder checksum in an installable cask and no separate version number to keep synchronized. See the [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook).

The one-time change from `com.snapper.Snapper` to `com.nikhilweee.snapper` requires granting Accessibility access again; JSON files remain in place. Rebuilding an ad hoc signed app may also require regranting permission.

## Generated files

`.build/` is disposable SwiftPM output, including icon previews. `build/` contains generated apps, ZIPs, and casks. Neither belongs in source control. Keep `Resources/AppIcon.icns`, `scripts/generate-icon.swift`, and `Casks/snapper.rb.in` as their sources. User layouts and display assignments live outside the repository in `~/Library/Application Support/Snapper/`.
