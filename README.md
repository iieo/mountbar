# MountBar

Menüleisten-App für macOS, die Linux- und Windows-Laufwerke (ext4, btrfs, xfs, NTFS und mehr)
über [anylinuxfs](https://github.com/nohajc/anylinuxfs) automatisch einhängt und auswirft.

## Installieren

```
./install.sh
```

Das Skript prüft Homebrew und Swift, installiert anylinuxfs und util-linux, baut die App und legt
sie nach `/Applications`. Nur bauen geht mit `./build.sh`, bauen und installieren mit
`./build.sh --install`.

## Einstellungen

- Automatisch einhängen beim Anstecken (an)
- Abziehen ohne Auswerfen (an): Linux-Dateisysteme werden mit `sync` eingehängt, jede Änderung
  landet sofort auf dem Laufwerk. Wer mitten im Kopieren abzieht, verliert trotzdem die Datei, die
  gerade geschrieben wird.
- Standardzugriff: lesen und schreiben (Standard) oder nur lesen
- Sprache: Englisch (Standard), Deutsch, Französisch, Spanisch
- Beim Anmelden starten

Beim ersten Start fragt die App einmal nach dem Administratorpasswort. Sie installiert dann
`/usr/local/libexec/mountbar-helper` (gehört root) und `/etc/sudoers.d/mountbar`, das genau diesen
Helfer ohne Passwort erlaubt. Ändert sich der Helfer in einer neuen Version, bietet die App an, ihn
zu aktualisieren.

anylinuxfs und blkid liegen in Homebrew-Ordnern, die dem Nutzer gehören, laufen aber als root. Der
Helfer speichert deshalb beim Einrichten einen Fingerabdruck (Inode, Größe, ctime) aller Dateien von
anylinuxfs, util-linux und gettext. Ändert sich etwas, etwa durch `brew upgrade`, verweigert er den
Dienst, bis du in der App mit deinem Passwort neu bestätigst.

## Wie es funktioniert

- Die App hört über DiskArbitration auf externe Laufwerke. Beim Anstecken liest der Helfer die
  Partitionstabelle (MBR oder GPT) selbst und erkennt das Dateisystem mit `blkid`.
- Normale Laufwerke werden direkt eingehängt (`anylinuxfs mount /dev/diskNsM`), auf Wunsch auch
  mit Schreibzugriff.
- Laufwerke, die eine falsche Größe melden (gefälschte Kapazität, defektes Gehäuse), bringen
  `blkid` und anylinuxfs zum Scheitern, weil beide am Geräteende lesen. Dafür legt der Helfer in
  `/var/db/mountbar/` ein leeres qcow2-Overlay an, das auf das Rohgerät zeigt und am Ende der
  Partition aufhört. Solche Laufwerke werden nur lesend eingehängt, und Schreibzugriffe würden im
  Overlay landen, nie auf dem Gerät.
- Partitionen, die macOS schon selbst eingehängt hat, fasst die App nicht an.

## Deinstallieren

```
sudo rm /usr/local/libexec/mountbar-helper /etc/sudoers.d/mountbar
sudo rm -rf /var/db/mountbar
rm -rf /Applications/MountBar.app
```
