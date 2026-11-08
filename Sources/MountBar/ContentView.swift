import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: DiskStore
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            Group {
                if !store.helperReady {
                    SetupView()
                } else if store.anylinuxfsMissing {
                    NoticeView(icon: "shippingbox",
                               title: "anylinuxfs fehlt",
                               text: "Installiere es mit\nbrew install nohajc/anylinuxfs/anylinuxfs")
                } else if store.disks.isEmpty {
                    NoticeView(icon: store.scanning ? "magnifyingglass" : "externaldrive.badge.questionmark",
                               title: store.scanning ? "Suche Laufwerke" : "Kein externes Laufwerk",
                               text: store.scanning ? "" : "Steck ein Laufwerk an. MountBar erkennt es von selbst.")
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(store.disks) { DiskCard(disk: $0) }
                        }
                        .padding(12)
                    }
                    .frame(maxHeight: 420)
                }
            }
            if let err = store.errorMessage {
                ErrorBanner(text: err) { store.errorMessage = nil }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            if showSettings {
                Divider().opacity(0.5)
                SettingsView()
            }
            Divider().opacity(0.5)
            footer
        }
        .frame(width: 360)
        .task { await store.scan() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("MountBar").font(.system(size: 13, weight: .semibold))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await store.scan() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(store.scanning ? 360 : 0))
                    .animation(store.scanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                               value: store.scanning)
            }
            .buttonStyle(IconButtonStyle())
            .help("Neu suchen")
            .disabled(!store.helperReady)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var subtitle: String {
        let n = store.mounts.count
        if n == 0 { return "Nichts eingehängt" }
        return n == 1 ? "1 Laufwerk eingehängt" : "\(n) Laufwerke eingehängt"
    }

    private var footer: some View {
        HStack {
            Button {
                withAnimation(.snappy(duration: 0.2)) { showSettings.toggle() }
            } label: {
                Label("Einstellungen", systemImage: showSettings ? "chevron.down" : "gearshape")
            }
            .buttonStyle(FooterButtonStyle())
            Spacer()
            if store.hasMounts {
                Button("Alle auswerfen") { Task { await store.unmountAll() } }
                    .buttonStyle(FooterButtonStyle())
            }
            Button("Beenden") { NSApp.terminate(nil) }
                .buttonStyle(FooterButtonStyle())
                .keyboardShortcut("q")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

struct DiskCard: View {
    @EnvironmentObject var store: DiskStore
    let disk: Disk

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "externaldrive.fill")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(disk.name.isEmpty ? disk.disk : disk.name)
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(formatBytes(disk.size)) · \(disk.disk)\(disk.protocol.map { " · \($0)" } ?? "")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if disk.hasFakeCapacity, let real = disk.readableBytes {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("Meldet \(formatBytes(disk.size)), lesbar sind nur \(formatBytes(real)). Wird nur lesend eingehängt. Daten bald sichern.")
                        .font(.system(size: 11))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if disk.partitions.isEmpty {
                Text("Keine Partitionen gefunden")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            ForEach(disk.partitions) { PartitionRow(disk: disk, part: $0) }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct PartitionRow: View {
    @EnvironmentObject var store: DiskStore
    let disk: Disk
    let part: Partition
    @State private var hovering = false

    private var key: String { DiskStore.key(disk.disk, part.index) }
    private var isBusy: Bool { store.busy.contains(key) }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(part.mount != nil ? Color.green.opacity(0.18) : Color.secondary.opacity(0.12))
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(part.mount != nil ? .green : .secondary)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(part.displayName).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Tag(text: part.fsDisplay)
                    if let m = part.mount, m.readonly { Tag(text: "Nur lesen") }
                }
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            actions
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(hovering ? Color.primary.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hovering = $0 }
        .contextMenu {
            if part.mountable && part.mount == nil {
                Button("Nur lesend einhängen") { Task { await store.mount(disk, part, readOnly: true) } }
                if part.writable {
                    Button("Mit Schreibzugriff einhängen") { Task { await store.mount(disk, part, readOnly: false) } }
                }
            }
            if let m = part.mount {
                Button("Im Finder öffnen") { store.openInFinder(m.mountpoint) }
                Button("Auswerfen") { Task { await store.unmount(m, key: key) } }
            }
        }
    }

    private var icon: String {
        if part.mount != nil { return "checkmark" }
        if !part.mountable { return "minus" }
        return "externaldrive"
    }

    private var detail: String {
        if let m = part.mount { return m.mountpoint }
        if let m = part.macosMount { return "\(m) · von macOS eingehängt" }
        if !part.readable { return "\(formatBytes(part.size)) · nicht lesbar" }
        if !part.mountable { return "\(formatBytes(part.size)) · wird nicht eingehängt" }
        return formatBytes(part.size)
    }

    @ViewBuilder private var actions: some View {
        if isBusy {
            ProgressView().controlSize(.small)
        } else if let m = part.mount {
            HStack(spacing: 4) {
                Button { store.openInFinder(m.mountpoint) } label: { Image(systemName: "folder") }
                    .buttonStyle(IconButtonStyle())
                    .help("Im Finder öffnen")
                Button { Task { await store.unmount(m, key: key) } } label: { Image(systemName: "eject.fill") }
                    .buttonStyle(IconButtonStyle())
                    .help("Auswerfen")
            }
        } else if let m = part.macosMount {
            Button { store.openInFinder(m) } label: { Image(systemName: "folder") }
                .buttonStyle(IconButtonStyle())
                .help("Im Finder öffnen")
        } else if part.mountable {
            Button("Einhängen") { Task { await store.mount(disk, part) } }
                .buttonStyle(PillButtonStyle())
        }
    }
}

struct SetupView: View {
    @EnvironmentObject var store: DiskStore
    @State private var installing = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text(Helper.isInstalled ? "Helfer aktualisieren" : "Einmal einrichten")
                .font(.system(size: 13, weight: .semibold))
            Text(Helper.isInstalled
                 ? "Diese Version von MountBar bringt einen neuen Helfer mit. macOS fragt dafür einmal nach deinem Passwort."
                 : "MountBar braucht einen kleinen Helfer mit Administratorrechten, um Laufwerke einzuhängen. macOS fragt dafür einmal nach deinem Passwort.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                installing = true
                Task {
                    await store.installHelper()
                    installing = false
                }
            } label: {
                if installing { ProgressView().controlSize(.small) } else { Text("Einrichten") }
            }
            .buttonStyle(PillButtonStyle(prominent: true))
            .disabled(installing)
        }
        .padding(20)
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: DiskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Beim Anstecken automatisch einhängen", isOn: $store.autoMount)
            Toggle("Standardmäßig nur lesend einhängen", isOn: $store.readOnlyDefault)
            Toggle("Beim Anmelden starten", isOn: Binding(
                get: { store.launchAtLogin },
                set: { store.setLaunchAtLogin($0) }
            ))
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .font(.system(size: 11))
        .padding(12)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

struct NoticeView: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.secondary)
            Text(title).font(.system(size: 13, weight: .semibold))
            if !text.isEmpty {
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
    }
}

struct ErrorBanner: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
            Text(text)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Spacer(minLength: 0)
            Button(action: dismiss) { Image(systemName: "xmark") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct Tag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Color.secondary.opacity(0.15), in: Capsule())
            .foregroundStyle(.secondary)
    }
}

struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, prominent ? 16 : 10)
            .padding(.vertical, prominent ? 6 : 4)
            .background(prominent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.accentColor.opacity(0.15)),
                        in: Capsule())
            .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(Color.accentColor))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .frame(width: 26, height: 26)
            .background(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
    }
}

struct FooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(configuration.isPressed ? 0.1 : 0), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
    }
}
