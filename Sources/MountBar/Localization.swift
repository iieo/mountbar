import Foundation

enum Language: String, CaseIterable, Identifiable {
    case en, de, fr, es

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .en: return "English"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .es: return "Español"
        }
    }
}

/// Übersetzungen. Die App stellt die Sprache selbst ein, unabhängig von macOS.
enum L {
    static var language: Language = .en

    static func t(_ key: String, _ args: CVarArg...) -> String {
        let entry = table[key]
        let format = entry?[language] ?? entry?[.en] ?? key
        return args.isEmpty ? format : String(format: format, arguments: args)
    }

    private static let table: [String: [Language: String]] = [
        "nothing_mounted": [.en: "Nothing mounted", .de: "Nichts eingehängt",
                            .fr: "Rien de monté", .es: "Nada montado"],
        "mounted_one": [.en: "1 drive mounted", .de: "1 Laufwerk eingehängt",
                        .fr: "1 disque monté", .es: "1 unidad montada"],
        "mounted_many": [.en: "%d drives mounted", .de: "%d Laufwerke eingehängt",
                         .fr: "%d disques montés", .es: "%d unidades montadas"],
        "rescan": [.en: "Scan again", .de: "Neu suchen", .fr: "Rechercher à nouveau", .es: "Buscar de nuevo"],
        "anylinuxfs_missing": [.en: "anylinuxfs is missing", .de: "anylinuxfs fehlt",
                               .fr: "anylinuxfs est absent", .es: "Falta anylinuxfs"],
        "anylinuxfs_install": [.en: "Install it with", .de: "Installiere es mit",
                               .fr: "Installe-le avec", .es: "Instálalo con"],
        "searching": [.en: "Looking for drives", .de: "Suche Laufwerke",
                      .fr: "Recherche de disques", .es: "Buscando unidades"],
        "no_disk": [.en: "No external drive", .de: "Kein externes Laufwerk",
                    .fr: "Aucun disque externe", .es: "Ninguna unidad externa"],
        "no_disk_text": [.en: "Plug in a drive. MountBar picks it up on its own.",
                         .de: "Steck ein Laufwerk an. MountBar erkennt es von selbst.",
                         .fr: "Branche un disque. MountBar le détecte tout seul.",
                         .es: "Conecta una unidad. MountBar la detecta solo."],
        "settings": [.en: "Settings", .de: "Einstellungen", .fr: "Réglages", .es: "Ajustes"],
        "eject_all": [.en: "Eject all", .de: "Alle auswerfen", .fr: "Tout éjecter", .es: "Expulsar todo"],
        "quit": [.en: "Quit", .de: "Beenden", .fr: "Quitter", .es: "Salir"],
        "fake_capacity": [
            .en: "Reports %@, but only %@ can be read. Mounted read only. Back up your data soon.",
            .de: "Meldet %@, lesbar sind nur %@. Wird nur lesend eingehängt. Sichere deine Daten bald.",
            .fr: "Annonce %@, mais seuls %@ sont lisibles. Monté en lecture seule. Sauvegarde tes données bientôt.",
            .es: "Indica %@, pero solo se pueden leer %@. Se monta solo en lectura. Haz copia de tus datos pronto."],
        "no_partitions": [.en: "No partitions found", .de: "Keine Partitionen gefunden",
                          .fr: "Aucune partition trouvée", .es: "No se encontraron particiones"],
        "partition_n": [.en: "Partition %d", .de: "Partition %d", .fr: "Partition %d", .es: "Partición %d"],
        "fs_unknown": [.en: "Unknown", .de: "Unbekannt", .fr: "Inconnu", .es: "Desconocido"],
        "read_only": [.en: "Read only", .de: "Nur lesen", .fr: "Lecture seule", .es: "Solo lectura"],
        "open_in_finder": [.en: "Show in Finder", .de: "Im Finder öffnen",
                           .fr: "Afficher dans le Finder", .es: "Mostrar en Finder"],
        "eject": [.en: "Eject", .de: "Auswerfen", .fr: "Éjecter", .es: "Expulsar"],
        "mount": [.en: "Mount", .de: "Einhängen", .fr: "Monter", .es: "Montar"],
        "mount_ro": [.en: "Mount read only", .de: "Nur lesend einhängen",
                     .fr: "Monter en lecture seule", .es: "Montar solo lectura"],
        "mount_rw": [.en: "Mount with write access", .de: "Mit Schreibzugriff einhängen",
                     .fr: "Monter en lecture et écriture", .es: "Montar con escritura"],
        "not_readable": [.en: "not readable", .de: "nicht lesbar", .fr: "illisible", .es: "no legible"],
        "not_mountable": [.en: "not mounted", .de: "wird nicht eingehängt",
                          .fr: "non monté", .es: "no se monta"],
        "by_macos": [.en: "mounted by macOS", .de: "von macOS eingehängt",
                     .fr: "monté par macOS", .es: "montado por macOS"],

        "setup_first": [.en: "One-time setup", .de: "Einmal einrichten",
                        .fr: "Configuration unique", .es: "Configuración única"],
        "setup_update": [.en: "Update helper", .de: "Helfer aktualisieren",
                         .fr: "Mettre à jour l’assistant", .es: "Actualizar asistente"],
        "setup_reconfirm": [.en: "Confirm again", .de: "Neu bestätigen",
                            .fr: "Confirmer à nouveau", .es: "Confirmar de nuevo"],
        "setup_first_text": [
            .en: "MountBar needs a small helper with administrator rights to mount drives. macOS asks for your password once.",
            .de: "MountBar braucht einen kleinen Helfer mit Administratorrechten, um Laufwerke einzuhängen. macOS fragt dafür einmal nach deinem Passwort.",
            .fr: "MountBar a besoin d’un petit assistant avec droits administrateur pour monter les disques. macOS te demande ton mot de passe une seule fois.",
            .es: "MountBar necesita un pequeño asistente con permisos de administrador para montar unidades. macOS te pedirá la contraseña una vez."],
        "setup_update_text": [
            .en: "This version of MountBar comes with a new helper. macOS asks for your password once.",
            .de: "Diese Version von MountBar bringt einen neuen Helfer mit. macOS fragt dafür einmal nach deinem Passwort.",
            .fr: "Cette version de MountBar apporte un nouvel assistant. macOS te demande ton mot de passe une fois.",
            .es: "Esta versión de MountBar trae un asistente nuevo. macOS te pedirá la contraseña una vez."],
        "setup_untrusted_text": [
            .en: "anylinuxfs or util-linux changed, probably through a Homebrew update. For safety the helper stops until you confirm with your password.",
            .de: "anylinuxfs oder util-linux hat sich geändert, wahrscheinlich durch ein Homebrew-Update. Zur Sicherheit pausiert der Helfer, bis du mit deinem Passwort bestätigst.",
            .fr: "anylinuxfs ou util-linux a changé, sans doute après une mise à jour Homebrew. Par sécurité, l’assistant attend ta confirmation avec ton mot de passe.",
            .es: "anylinuxfs o util-linux ha cambiado, seguramente por una actualización de Homebrew. Por seguridad, el asistente espera a que confirmes con tu contraseña."],
        "setup_button": [.en: "Set up", .de: "Einrichten", .fr: "Configurer", .es: "Configurar"],

        "auto_mount": [.en: "Mount automatically when plugged in", .de: "Beim Anstecken automatisch einhängen",
                       .fr: "Monter automatiquement au branchement", .es: "Montar automáticamente al conectar"],
        "default_access": [.en: "Default access", .de: "Standardzugriff", .fr: "Accès par défaut", .es: "Acceso por defecto"],
        "access_rw": [.en: "Read & write", .de: "Lesen & schreiben", .fr: "Lecture & écriture", .es: "Lectura y escritura"],
        "access_ro": [.en: "Read only", .de: "Nur lesen", .fr: "Lecture seule", .es: "Solo lectura"],
        "safe_unplug": [.en: "Safe to unplug without ejecting", .de: "Abziehen ohne Auswerfen erlauben",
                        .fr: "Débrancher sans éjecter", .es: "Desconectar sin expulsar"],
        "safe_unplug_hint": [
            .en: "Writes go straight to the drive. Slower, but you can unplug as soon as copying has finished.",
            .de: "Jede Änderung landet sofort auf dem Laufwerk. Etwas langsamer, aber du kannst abziehen, sobald nichts mehr kopiert wird.",
            .fr: "Chaque écriture va directement sur le disque. Un peu plus lent, mais tu peux débrancher dès que la copie est terminée.",
            .es: "Cada escritura va directa a la unidad. Algo más lento, pero puedes desconectar en cuanto termine la copia."],
        "launch_at_login": [.en: "Open at login", .de: "Beim Anmelden starten",
                            .fr: "Ouvrir à la connexion", .es: "Abrir al iniciar sesión"],
        "language": [.en: "Language", .de: "Sprache", .fr: "Langue", .es: "Idioma"],
        "autostart": [.en: "Open at login", .de: "Autostart", .fr: "Ouverture à la connexion", .es: "Inicio automático"],

        "err_not_installed": [.en: "The helper is not set up yet.", .de: "Der Helfer ist noch nicht eingerichtet.",
                              .fr: "L’assistant n’est pas encore configuré.", .es: "El asistente aún no está configurado."],
        "err_unknown_disk": [.en: "Unknown drive or not an external drive", .de: "Unbekanntes oder kein externes Laufwerk",
                             .fr: "Disque inconnu ou non externe", .es: "Unidad desconocida o no externa"],
        "err_bad_command": [.en: "Invalid request to the helper", .de: "Ungültige Anfrage an den Helfer",
                            .fr: "Requête invalide pour l’assistant", .es: "Petición no válida al asistente"],
        "err_no_anylinuxfs": [.en: "anylinuxfs is not installed", .de: "anylinuxfs ist nicht installiert",
                              .fr: "anylinuxfs n’est pas installé", .es: "anylinuxfs no está instalado"],
        "err_not_found": [.en: "Partition not found", .de: "Partition nicht gefunden",
                          .fr: "Partition introuvable", .es: "Partición no encontrada"],
        "err_not_mountable": [.en: "This partition cannot be mounted", .de: "Diese Partition lässt sich nicht einhängen",
                              .fr: "Cette partition ne peut pas être montée", .es: "Esta partición no se puede montar"],
        "err_fake_rw": [.en: "This drive reports a wrong size. It can only be mounted read only.",
                        .de: "Dieses Laufwerk meldet eine falsche Größe. Es lässt sich nur lesend einhängen.",
                        .fr: "Ce disque annonce une taille fausse. Il ne peut être monté qu’en lecture seule.",
                        .es: "Esta unidad indica un tamaño falso. Solo se puede montar en lectura."],
        "err_mount_failed": [.en: "Mounting failed", .de: "Einhängen fehlgeschlagen",
                             .fr: "Échec du montage", .es: "Error al montar"],
        "err_no_mount": [.en: "Nothing is mounted there", .de: "Dort ist nichts eingehängt",
                         .fr: "Rien n’est monté à cet endroit", .es: "No hay nada montado ahí"],
        "err_unmount_failed": [.en: "Ejecting failed", .de: "Auswerfen fehlgeschlagen",
                               .fr: "Échec de l’éjection", .es: "Error al expulsar"],
        "err_timeout": [.en: "The helper did not respond in time", .de: "Der Helfer hat nicht rechtzeitig geantwortet",
                        .fr: "L’assistant n’a pas répondu à temps", .es: "El asistente no respondió a tiempo"],
        "err_internal": [.en: "Internal helper error", .de: "Interner Fehler im Helfer",
                         .fr: "Erreur interne de l’assistant", .es: "Error interno del asistente"],
        "err_disk_read": [.en: "Could not read this drive", .de: "Laufwerk konnte nicht gelesen werden",
                          .fr: "Impossible de lire ce disque", .es: "No se pudo leer esta unidad"],
        "err_unexpected": [.en: "Unexpected reply from the helper", .de: "Unerwartete Antwort vom Helfer",
                           .fr: "Réponse inattendue de l’assistant", .es: "Respuesta inesperada del asistente"],
        "err_setup_files": [.en: "Setup files are missing from the app", .de: "Installationsdateien fehlen in der App",
                            .fr: "Fichiers d’installation absents de l’app", .es: "Faltan archivos de instalación en la app"],
        "err_setup_cancelled": [.en: "Setup was cancelled", .de: "Einrichtung abgebrochen",
                                .fr: "Configuration annulée", .es: "Configuración cancelada"],
    ]
}
