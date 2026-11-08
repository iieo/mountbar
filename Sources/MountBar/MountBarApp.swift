import SwiftUI

@main
struct MountBarApp: App {
    @StateObject private var store = DiskStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(store)
        } label: {
            Image(systemName: store.hasMounts ? "externaldrive.fill.badge.checkmark" : "externaldrive")
        }
        .menuBarExtraStyle(.window)
    }
}
