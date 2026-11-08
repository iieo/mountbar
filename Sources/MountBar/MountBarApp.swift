import AppKit
import Combine
import SwiftUI

// Reiner AppKit-Start: Eine SwiftUI-App bräuchte eine Szene, und selbst eine leere
// Settings-Szene öffnet beim Start ein Fenster.
@main
enum MountBarMain {
    @MainActor static let delegate = AppDelegate()

    @MainActor static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}

/// Eigenes Menüleisten-Symbol mit NSPopover statt MenuBarExtra. Das Fenster von
/// MenuBarExtra übernimmt Größenänderungen nach dem ersten Öffnen nicht zuverlässig,
/// der Inhalt lief dann über den Rand. NSPopover folgt der bevorzugten Größe.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var store: DiskStore!
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store = DiskStore()

        let host = NSHostingController(rootView: ContentView().environmentObject(store))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = false

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.action = #selector(toggle)
        statusItem.button?.target = self
        updateIcon(mounted: false)

        store.$mounts
            .map { !$0.isEmpty }
            .removeDuplicates()
            .sink { [weak self] in self?.updateIcon(mounted: $0) }
            .store(in: &cancellables)
    }

    private func updateIcon(mounted: Bool) {
        let name = mounted ? "externaldrive.fill.badge.checkmark" : "externaldrive"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "MountBar")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    @objc private func toggle() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate()
            Task { await store.scan() }
        }
    }
}
