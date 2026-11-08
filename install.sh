#!/bin/bash
# Installs MountBar and its dependencies.
#   ./install.sh              from a cloned repository
#   curl -fsSL https://raw.githubusercontent.com/iieo/mountbar/main/install.sh | bash
set -euo pipefail

REPO="https://github.com/iieo/mountbar.git"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname)" == "Darwin" ]] || die "MountBar only runs on macOS."
[[ "$(uname -m)" == "arm64" ]] || say "Note: anylinuxfs is built for Apple silicon. It may fail on Intel Macs."
command -v brew >/dev/null || die "Homebrew is missing. Install it from https://brew.sh and run this script again."
xcrun --find swift >/dev/null 2>&1 || die "Swift is missing. Install the Command Line Tools with: xcode-select --install"

say "Installing anylinuxfs and util-linux"
brew trust nohajc/anylinuxfs >/dev/null 2>&1 || true
brew install nohajc/anylinuxfs/anylinuxfs util-linux

# Piped into bash there is no script file, so BASH_SOURCE points nowhere.
SELF="${BASH_SOURCE[0]:-}"
if [[ -n "$SELF" && -f "$SELF" && -f "$(dirname "$SELF")/Package.swift" ]]; then
    SRC="$(cd "$(dirname "$SELF")" && pwd)"
else
    TMPDIR_CLONE="$(mktemp -d)"
    trap 'rm -rf "$TMPDIR_CLONE"' EXIT
    SRC="$TMPDIR_CLONE/mountbar"
    say "Downloading MountBar"
    git clone --depth 1 "$REPO" "$SRC"
fi

say "Building MountBar and installing it to /Applications"
"$SRC/build.sh" --install

cat <<'MSG'

MountBar is running. Look for the drive icon in the menu bar.
On first use click "Set up". macOS asks for your password once.
MSG
