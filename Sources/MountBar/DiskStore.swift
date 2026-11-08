import AppKit
import Foundation
import ServiceManagement

@MainActor
final class DiskStore: ObservableObject {
    @Published var disks: [Disk] = []
    @Published var mounts: [MountInfo] = []
    @Published var scanning = false
    @Published var busy: Set<String> = []
    @Published var errorMessage: String?
    @Published var helperReady = Helper.isInstalled && !Helper.isOutdated
    @Published var anylinuxfsMissing = false
    @Published var untrusted = false
    @Published var untrustedDetail = ""
    @Published var language: Language {
        didSet {
            L.language = language
            UserDefaults.standard.set(language.rawValue, forKey: "language")
        }
    }

    @Published var autoMount: Bool {
        didSet { UserDefaults.standard.set(autoMount, forKey: "autoMount") }
    }
    @Published var openAfterMount: Bool {
        didSet { UserDefaults.standard.set(openAfterMount, forKey: "openAfterMount") }
    }
    @Published var fullAccess: Bool {
        didSet { UserDefaults.standard.set(fullAccess, forKey: "fullAccess") }
    }
    @Published var safeUnplug: Bool {
        didSet { UserDefaults.standard.set(safeUnplug, forKey: "safeUnplug") }
    }
    @Published var readOnlyDefault: Bool {
        didSet { UserDefaults.standard.set(readOnlyDefault, forKey: "readOnlyDefault") }
    }
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    private var watcher: DiskWatcher?
    private var statusTimer: Timer?
    private var knownDisks: Set<String> = []
    private var scanTask: Task<Void, Never>?
    private var rescanRequested = false

    var hasMounts: Bool { !mounts.isEmpty }

    init() {
        UserDefaults.standard.register(defaults: [
            "autoMount": true, "readOnlyDefault": false, "safeUnplug": true,
            "openAfterMount": true, "fullAccess": true, "language": "en",
        ])
        fullAccess = UserDefaults.standard.bool(forKey: "fullAccess")
        openAfterMount = UserDefaults.standard.bool(forKey: "openAfterMount")
        safeUnplug = UserDefaults.standard.bool(forKey: "safeUnplug")
        autoMount = UserDefaults.standard.bool(forKey: "autoMount")
        readOnlyDefault = UserDefaults.standard.bool(forKey: "readOnlyDefault")
        let lang = Language(rawValue: UserDefaults.standard.string(forKey: "language") ?? "en") ?? .en
        language = lang
        L.language = lang

        watcher = DiskWatcher()
        watcher?.onAppear = { [weak self] disk in
            Task { @MainActor in self?.diskAppeared(disk) }
        }
        watcher?.onDisappear = { [weak self] disk in
            Task { @MainActor in self?.diskDisappeared(disk) }
        }
        watcher?.start()

        statusTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshStatus() }
        }
        Task { await scan() }
    }

    static func key(_ disk: String, _ index: Int) -> String { "\(disk)s\(index)" }

    // MARK: Ereignisse

    private func diskAppeared(_ disk: String) {
        guard !knownDisks.contains(disk) else { return }
        knownDisks.insert(disk)
        Task {
            // Partitionen und Treiber brauchen nach dem Anstecken einen Moment.
            try? await Task.sleep(for: .seconds(2))
            await scan()
            if autoMount { await autoMountDisk(disk) }
        }
    }

    private func diskDisappeared(_ disk: String) {
        knownDisks.remove(disk)
        let stale = mounts.filter { $0.diskID == disk }
        Task {
            // Der Helfer löst den Mount hart, weil das Gerät nicht mehr existiert.
            for m in stale {
                _ = try? await Helper.run(["unmount", m.mountpoint], as: HelperReply.self, timeout: 150)
            }
            await scan()
        }
    }

    // MARK: Aktionen

    /// Gleichzeitige Anfragen werden zu höchstens einem weiteren Lauf gebündelt,
    /// damit ein älteres Ergebnis nie ein neueres überschreibt.
    func scan() async {
        if let running = scanTask {
            rescanRequested = true
            await running.value
            return
        }
        let task = Task {
            await self.scanLoop()
            // Hier zurücksetzen, nicht beim Aufrufer: sonst ginge eine Anfrage verloren,
            // die zwischen Ende der Schleife und Rückkehr des Aufrufers eintrifft.
            self.scanTask = nil
        }
        scanTask = task
        await task.value
    }

    private func scanLoop() async {
        repeat {
            rescanRequested = false
            await scanOnce()
        } while rescanRequested
    }

    private func scanOnce() async {
        guard Helper.isInstalled, !Helper.isOutdated, !untrusted else {
            helperReady = false
            return
        }
        helperReady = true
        scanning = true
        defer { scanning = false }
        do {
            let r = try await Helper.run(["scan"], as: ScanResult.self, timeout: 180)
            disks = r.disks
            mounts = r.mounts
            anylinuxfsMissing = !r.anylinuxfs
        } catch {
            handle(error)
        }
    }

    private func handle(_ error: Error, prefix: String? = nil) {
        switch error {
        case HelperError.notInstalled:
            helperReady = false
        case HelperError.untrusted(let detail):
            helperReady = false
            untrusted = true
            untrustedDetail = detail
        default:
            errorMessage = [prefix, error.localizedDescription].compactMap { $0 }.joined(separator: ": ")
        }
    }

    func refreshStatus() async {
        guard helperReady, busy.isEmpty, scanTask == nil else { return }
        guard let r = try? await Helper.run(["status"], as: StatusResult.self) else { return }
        if r.mounts != mounts {
            await scan()
        }
    }

    func mount(_ disk: Disk, _ part: Partition, readOnly: Bool? = nil) async {
        let key = Self.key(disk.disk, part.index)
        guard !busy.contains(key) else { return }
        busy.insert(key)
        defer { busy.remove(key) }
        let ro = !part.writable || (readOnly ?? readOnlyDefault)
        do {
            var args = ["mount", disk.disk, String(part.index), ro ? "ro" : "rw"]
            if !ro && safeUnplug { args.append("sync") }
            if fullAccess { args.append("owner") }
            let reply = try await Helper.run(args, as: HelperReply.self, timeout: 330)
            errorMessage = nil
            if openAfterMount, reply.already != true, let mp = reply.mountpoint {
                openInFinder(mp)
            }
        } catch {
            handle(error, prefix: part.displayName)
        }
        await scan()
    }

    func unmount(_ mount: MountInfo, rescan: Bool = true) async {
        let key = Self.ejectKey(mount)
        guard !busy.contains(key) else { return }
        busy.insert(key)
        defer { busy.remove(key) }
        do {
            _ = try await Helper.run(["unmount", mount.mountpoint], as: HelperReply.self, timeout: 150)
            errorMessage = nil
        } catch {
            handle(error)
        }
        if rescan { await scan() }
    }

    /// Busy-Schlüssel fürs Auswerfen. Zeile und "Alle auswerfen" müssen denselben nutzen.
    static func ejectKey(_ m: MountInfo) -> String { "eject:\(m.mountpoint)" }

    func unmountAll() async {
        for m in mounts {
            await unmount(m, rescan: false)
        }
        await scan()
    }

    private func autoMountDisk(_ id: String) async {
        guard let disk = disks.first(where: { $0.disk == id }) else { return }
        for part in disk.partitions where part.auto && part.mount == nil {
            await mount(disk, part)
        }
    }

    func autoMountAll() async {
        for disk in disks { await autoMountDisk(disk.disk) }
    }

    func openInFinder(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func installHelper() async {
        // Nur die Helfer-Datei zählt: Wer von der alten gemeinsamen sudoers-Datei kommt,
        // aktualisiert und installiert nicht zum ersten Mal.
        let firstInstall = !FileManager.default.fileExists(atPath: Helper.path)
        do {
            try await Helper.install()
            untrusted = false
            untrustedDetail = ""
            helperReady = Helper.isInstalled && !Helper.isOutdated
            errorMessage = nil
            await scan()
            // Nach einer Aktualisierung nichts einhängen, was der Nutzer vorher ausgeworfen hat.
            if firstInstall && autoMount { await autoMountAll() }
        } catch {
            handle(error)
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            handle(error, prefix: L.t("autostart"))
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
