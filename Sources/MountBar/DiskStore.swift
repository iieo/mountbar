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
    @Published var language: Language {
        didSet {
            L.language = language
            UserDefaults.standard.set(language.rawValue, forKey: "language")
        }
    }

    @Published var autoMount: Bool {
        didSet { UserDefaults.standard.set(autoMount, forKey: "autoMount") }
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

    var hasMounts: Bool { !mounts.isEmpty }

    init() {
        UserDefaults.standard.register(defaults: ["autoMount": true, "readOnlyDefault": false, "safeUnplug": true, "language": "en"])
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
            for m in stale {
                _ = try? await Helper.run(["unmount", m.mountpoint], as: HelperReply.self)
            }
            await scan()
        }
    }

    // MARK: Aktionen

    func scan() async {
        helperReady = Helper.isInstalled && !Helper.isOutdated
        guard helperReady else { return }
        scanning = true
        defer { scanning = false }
        do {
            let r = try await Helper.run(["scan"], as: ScanResult.self)
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
        case HelperError.untrusted:
            helperReady = false
            untrusted = true
        default:
            errorMessage = [prefix, error.localizedDescription].compactMap { $0 }.joined(separator: ": ")
        }
    }

    func refreshStatus() async {
        guard helperReady, busy.isEmpty, !scanning else { return }
        guard let r = try? await Helper.run(["status"], as: StatusResult.self) else { return }
        if r.mounts != mounts {
            await scan()
        }
    }

    func mount(_ disk: Disk, _ part: Partition, readOnly: Bool? = nil) async {
        let key = Self.key(disk.disk, part.index)
        busy.insert(key)
        defer { busy.remove(key) }
        let ro = !part.writable || (readOnly ?? readOnlyDefault)
        do {
            var args = ["mount", disk.disk, String(part.index), ro ? "ro" : "rw"]
            if !ro && safeUnplug { args.append("sync") }
            _ = try await Helper.run(args,
                                     as: HelperReply.self, timeout: 330)
            errorMessage = nil
        } catch {
            handle(error, prefix: part.displayName)
        }
        await scan()
    }

    func unmount(_ mount: MountInfo, key: String, rescan: Bool = true) async {
        busy.insert(key)
        defer { busy.remove(key) }
        do {
            _ = try await Helper.run(["unmount", mount.mountpoint], as: HelperReply.self)
            errorMessage = nil
        } catch {
            handle(error)
        }
        if rescan { await scan() }
    }

    func unmountAll() async {
        for m in mounts {
            await unmount(m, key: m.mountpoint, rescan: false)
        }
        await scan()
    }

    private func autoMountDisk(_ id: String) async {
        guard let disk = disks.first(where: { $0.disk == id }) else { return }
        for part in disk.partitions where part.mountable && part.mount == nil {
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
        do {
            try await Helper.install()
            helperReady = Helper.isInstalled && !Helper.isOutdated
            errorMessage = nil
            untrusted = false
            await scan()
            if autoMount { await autoMountAll() }
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
