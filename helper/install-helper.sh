#!/bin/bash
# Installiert den MountBar-Helfer als root und erlaubt ihn dem Nutzer ohne Passwort.
# Aufruf (als root): install-helper.sh <helper-quelle> <benutzername>
set -euo pipefail

SRC="$1"
USER_NAME="$2"
DEST=/usr/local/libexec/mountbar-helper
SUDOERS=/etc/sudoers.d/mountbar

[[ "$USER_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Ungültiger Benutzername" >&2; exit 1; }

install -d -o root -g wheel -m 755 /usr/local/libexec
install -o root -g wheel -m 755 "$SRC" "$DEST"

TMP=$(mktemp)
echo "$USER_NAME ALL=(root) NOPASSWD: $DEST" > "$TMP"
chmod 440 "$TMP"
visudo -cf "$TMP" >/dev/null
install -o root -g wheel -m 440 "$TMP" "$SUDOERS"
rm -f "$TMP"

# Fingerabdruck von anylinuxfs und util-linux festhalten. Der Helfer verweigert
# danach jeden Dienst, sobald sich dort etwas ändert.
env -u SUDO_USER -u SUDO_UID -u SUDO_GID -u SUDO_COMMAND "$DEST" trust >/dev/null
