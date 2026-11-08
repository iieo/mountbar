import DiskArbitration
import Foundation

/// Meldet externe, ganze Laufwerke beim Anstecken und Abziehen.
final class DiskWatcher {
    var onAppear: ((String) -> Void)?
    var onDisappear: ((String) -> Void)?

    private let session: DASession

    init?() {
        guard let s = DASessionCreate(kCFAllocatorDefault) else { return nil }
        session = s
    }

    func start() {
        let match: CFDictionary = [
            kDADiskDescriptionMediaWholeKey as String: true,
            kDADiskDescriptionDeviceInternalKey as String: false,
        ] as CFDictionary
        let ctx = Unmanaged.passUnretained(self).toOpaque()

        DARegisterDiskAppearedCallback(session, match, { disk, ctx in
            guard let ctx, let name = DADiskGetBSDName(disk) else { return }
            let watcher = Unmanaged<DiskWatcher>.fromOpaque(ctx).takeUnretainedValue()
            watcher.onAppear?(String(cString: name))
        }, ctx)

        DARegisterDiskDisappearedCallback(session, match, { disk, ctx in
            guard let ctx, let name = DADiskGetBSDName(disk) else { return }
            let watcher = Unmanaged<DiskWatcher>.fromOpaque(ctx).takeUnretainedValue()
            watcher.onDisappear?(String(cString: name))
        }, ctx)

        DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }
}
