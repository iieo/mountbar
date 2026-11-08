#!/bin/bash
# Installiert MountBar mit allen Abhängigkeiten.
#   ./install.sh              aus einem geklonten Repository
#   curl -fsSL https://raw.githubusercontent.com/iieo/mountbar/main/install.sh | bash
set -euo pipefail

REPO="https://github.com/iieo/mountbar.git"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mFehler:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname)" == "Darwin" ]] || die "MountBar läuft nur auf macOS."
[[ "$(uname -m)" == "arm64" ]] || say "Hinweis: anylinuxfs ist für Apple Silicon gebaut. Auf Intel kann es scheitern."
command -v brew >/dev/null || die "Homebrew fehlt. Installiere es von https://brew.sh und starte das Skript erneut."
xcrun --find swift >/dev/null 2>&1 || die "Swift fehlt. Installiere die Command Line Tools mit: xcode-select --install"

say "Installiere anylinuxfs und util-linux"
brew trust nohajc/anylinuxfs >/dev/null 2>&1 || true
brew install nohajc/anylinuxfs/anylinuxfs util-linux

if [[ -f "$(dirname "$0")/Package.swift" ]]; then
    SRC="$(cd "$(dirname "$0")" && pwd)"
else
    SRC="$(mktemp -d)/mountbar"
    say "Lade MountBar"
    git clone --depth 1 "$REPO" "$SRC"
fi

say "Baue MountBar und installiere die App nach /Applications"
"$SRC/build.sh" --install

cat <<'EOF'

MountBar läuft jetzt. Du findest das Laufwerk-Symbol oben in der Menüleiste.
Beim ersten Öffnen klickst du auf "Set up". macOS fragt dann einmal nach deinem Passwort.
EOF
