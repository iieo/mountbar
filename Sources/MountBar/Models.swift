import Foundation

struct ScanResult: Decodable {
    var anylinuxfs: Bool
    var blkid: Bool
    var disks: [Disk]
    var mounts: [MountInfo]
}

struct StatusResult: Decodable {
    var mounts: [MountInfo]
}

struct MountInfo: Decodable, Hashable {
    var source: String
    var mountpoint: String
    var fstype: String
    var readonly: Bool

    var diskID: String? {
        source.range(of: #"disk[0-9]+"#, options: .regularExpression).map { String(source[$0]) }
    }
}

struct Disk: Decodable, Identifiable, Hashable {
    var disk: String
    var name: String
    var size: Int64
    var `protocol`: String?
    var scheme: String
    var endReadable: Bool
    var readableBytes: Int64?
    var partitions: [Partition]
    var error: String?

    var id: String { disk }
    var hasFakeCapacity: Bool { !endReadable && readableBytes != nil }
}

struct Partition: Decodable, Identifiable, Hashable {
    var index: Int
    var start: Int64
    var size: Int64
    var ptype: String
    var fstype: String?
    var label: String?
    var uuid: String?
    var readable: Bool
    var mountable: Bool
    var writable: Bool
    var mount: MountInfo?
    var macosMount: String?

    var id: Int { index }

    var displayName: String {
        if let label, !label.isEmpty { return label }
        return L.t("partition_n", index)
    }

    var fsDisplay: String {
        switch fstype {
        case "ntfs": return "NTFS"
        case "exfat": return "exFAT"
        case "vfat": return "FAT"
        case "zfs_member": return "ZFS"
        case "swap": return "Swap"
        case "crypto_LUKS": return "LUKS"
        case "LVM2_member": return "LVM"
        case nil: return L.t("fs_unknown")
        default: return fstype!
        }
    }
}

struct HelperReply: Decodable {
    var ok: Bool?
    var error: String?
    var code: String?
    var mountpoint: String?
}

func formatBytes(_ n: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
}
