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

    @Published var autoMount: Bool {
        didSet { UserDefaults.standard.set(autoMount, forKey: "autoMount") }
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
        UserDefaults.standard.register(defaults: ["autoMount": true, "readOnlyDefault": true])
        autoMount = UserDefaults.standard.bool(forKey: "autoMount")
        readOnlyDefault = UserDefaults.standard.bool(forKey: "readOnlyDefault")

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
        } catch HelperError.notInstalled {
            helperReady = false
        } catch {
            errorMessage = error.localizedDescription
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
            _ = try await Helper.run(["mount", disk.disk, String(part.index), ro ? "ro" : "rw"], as: HelperReply.self)
            errorMessage = nil
        } catch {
            errorMessage = "\(part.displayName): \(error.localizedDescription)"
        }
        await scan()
    }

    func unmount(_ mount: MountInfo, key: String) async {
        busy.insert(key)
        defer { busy.remove(key) }
        do {
            _ = try await Helper.run(["unmount", mount.mountpoint], as: HelperReply.self)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        await scan()
    }

    func unmountAll() async {
        for disk in disks {
            for part in disk.partitions {
                if let m = part.mount { await unmount(m, key: Self.key(disk.disk, part.index)) }
            }
        }
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
            await scan()
            if autoMount { await autoMountAll() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            errorMessage = "Autostart: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
