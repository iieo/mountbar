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
                               title: L.t("anylinuxfs_missing"),
                               text: "\(L.t("anylinuxfs_install"))\nbrew install nohajc/anylinuxfs/anylinuxfs")
                } else if store.disks.isEmpty {
                    NoticeView(icon: store.scanning ? "magnifyingglass" : "externaldrive.badge.questionmark",
                               title: store.scanning ? L.t("searching") : L.t("no_disk"),
                               text: store.scanning ? "" : L.t("no_disk_text"))
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
                ZStack {
                    Image(systemName: "arrow.clockwise").opacity(store.scanning ? 0 : 1)
                    if store.scanning {
                        ProgressView().controlSize(.small).scaleEffect(0.7)
                    }
                }
            }
            .buttonStyle(IconButtonStyle())
            .help(L.t("rescan"))
            .disabled(!store.helperReady || store.scanning)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var subtitle: String {
        switch store.mounts.count {
        case 0: return L.t("nothing_mounted")
        case 1: return L.t("mounted_one")
        case let n: return L.t("mounted_many", n)
        }
    }

    private var footer: some View {
        HStack {
            Button {
                withAnimation(.snappy(duration: 0.2)) { showSettings.toggle() }
            } label: {
                Label(L.t("settings"), systemImage: showSettings ? "chevron.down" : "gearshape")
            }
            .buttonStyle(FooterButtonStyle())
            Spacer()
            if store.hasMounts {
                Button(L.t("eject_all")) { Task { await store.unmountAll() } }
                    .buttonStyle(FooterButtonStyle())
            }
            Button(L.t("quit")) { NSApp.terminate(nil) }
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
                    Text(L.t("fake_capacity", formatBytes(disk.size), formatBytes(real)))
                        .font(.system(size: 11))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if let err = disk.error {
                Text("\(L.t("err_disk_read")): \(err)")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if disk.partitions.isEmpty {
                Text(L.t("no_partitions"))
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
    private var isBusy: Bool { store.busy.contains(key) || part.mount.map { store.busy.contains($0.mountpoint) } == true }

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
                    if let m = part.mount, m.readonly { Tag(text: L.t("read_only")) }
                }
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
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
                if part.writable {
                    Button(L.t("mount_rw")) { Task { await store.mount(disk, part, readOnly: false) } }
                }
                Button(L.t("mount_ro")) { Task { await store.mount(disk, part, readOnly: true) } }
            }
            if let m = part.mount {
                Button(L.t("open_in_finder")) { store.openInFinder(m.mountpoint) }
                Button(L.t("eject")) { Task { await store.unmount(m, key: key) } }
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
        if let m = part.macosMount { return "\(m) · \(L.t("by_macos"))" }
        if !part.readable { return "\(formatBytes(part.size)) · \(L.t("not_readable"))" }
        if !part.mountable { return "\(formatBytes(part.size)) · \(L.t("not_mountable"))" }
        return formatBytes(part.size)
    }

    @ViewBuilder private var actions: some View {
        if isBusy {
            ProgressView().controlSize(.small)
        } else if let m = part.mount {
            HStack(spacing: 4) {
                Button { store.openInFinder(m.mountpoint) } label: { Image(systemName: "folder") }
                    .buttonStyle(IconButtonStyle())
                    .help(L.t("open_in_finder"))
                Button { Task { await store.unmount(m, key: key) } } label: { Image(systemName: "eject.fill") }
                    .buttonStyle(IconButtonStyle())
                    .help(L.t("eject"))
            }
        } else if let m = part.macosMount {
            Button { store.openInFinder(m) } label: { Image(systemName: "folder") }
                .buttonStyle(IconButtonStyle())
                .help(L.t("open_in_finder"))
        } else if part.mountable {
            Button(L.t("mount")) { Task { await store.mount(disk, part) } }
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
            Text(title).font(.system(size: 13, weight: .semibold))
            Text(text)
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
                if installing { ProgressView().controlSize(.small) } else { Text(L.t("setup_button")) }
            }
            .buttonStyle(PillButtonStyle(prominent: true))
            .disabled(installing)
        }
        .padding(20)
    }

    private var title: String {
        if store.untrusted { return L.t("setup_reconfirm") }
        return Helper.isInstalled ? L.t("setup_update") : L.t("setup_first")
    }

    private var text: String {
        if store.untrusted { return L.t("setup_untrusted_text") }
        return Helper.isInstalled ? L.t("setup_update_text") : L.t("setup_first_text")
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: DiskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(L.t("auto_mount"), isOn: $store.autoMount)
                .toggleStyle(.switch)
            Toggle(L.t("open_after_mount"), isOn: $store.openAfterMount)
                .toggleStyle(.switch)
            Toggle(L.t("safe_unplug"), isOn: $store.safeUnplug)
                .toggleStyle(.switch)
            Text(L.t("safe_unplug_hint"))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle(L.t("launch_at_login"), isOn: Binding(
                get: { store.launchAtLogin },
                set: { store.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)

            HStack {
                Text(L.t("default_access"))
                Spacer()
                Picker("", selection: $store.readOnlyDefault) {
                    Text(L.t("access_rw")).tag(false)
                    Text(L.t("access_ro")).tag(true)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
            HStack {
                Text(L.t("language"))
                Spacer()
                Picker("", selection: $store.language) {
                    ForEach(Language.allCases) { Text($0.nativeName).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
        }
        .controlSize(.small)
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
            .fixedSize()
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
