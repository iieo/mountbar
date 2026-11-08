# MountBar

Menüleisten-App für macOS, die Linux- und Windows-Laufwerke (ext4, btrfs, xfs, NTFS und mehr)
über [anylinuxfs](https://github.com/nohajc/anylinuxfs) automatisch einhängt und auswirft.

## Voraussetzungen

```
brew install nohajc/anylinuxfs/anylinuxfs util-linux
```

## Bauen und installieren

```
./build.sh            # baut build/MountBar.app
./build.sh --install  # kopiert nach /Applications und startet
```

Beim ersten Start fragt die App einmal nach dem Administratorpasswort. Sie installiert dann
`/usr/local/libexec/mountbar-helper` (gehört root) und `/etc/sudoers.d/mountbar`, das genau diesen
Helfer ohne Passwort erlaubt. Ändert sich der Helfer in einer neuen Version, bietet die App an, ihn
zu aktualisieren.

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
