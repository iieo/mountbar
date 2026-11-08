import Foundation

enum HelperError: LocalizedError {
    case notInstalled
    case untrusted
    case failed(code: String, detail: String = "")

    var errorDescription: String? {
        switch self {
        case .notInstalled: return L.t("err_not_installed")
        case .untrusted: return L.t("setup_untrusted_text")
        case .failed(let code, let detail):
            let base = L.t("err_\(code)")
            if base == "err_\(code)" { return detail.isEmpty ? L.t("err_internal") : detail }
            return detail.isEmpty ? base : "\(base): \(detail)"
        }
    }
}

/// Ruft den privilegierten Helfer über `sudo -n` auf. Die sudoers-Regel aus der
/// Einrichtung erlaubt genau diese eine Datei ohne Passwort.
enum Helper {
    static let path = "/usr/local/libexec/mountbar-helper"
    static let sudoersPath = "/etc/sudoers.d/mountbar"

    static var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: path)
            && FileManager.default.fileExists(atPath: sudoersPath)
    }

    /// Weicht der installierte Helfer vom mitgelieferten ab, muss er neu eingerichtet werden.
    static var isOutdated: Bool {
        guard let bundled = Bundle.main.path(forResource: "mountbar-helper", ofType: nil) else { return false }
        return FileManager.default.contents(atPath: bundled) != FileManager.default.contents(atPath: path)
    }

    static func run<T: Decodable>(_ args: [String], as type: T.Type, timeout: TimeInterval = 120) async throws -> T {
        guard FileManager.default.isExecutableFile(atPath: path) else { throw HelperError.notInstalled }
        let data = try await exec("/usr/bin/sudo", ["-n", path] + args, timeout: timeout)
        if let reply = try? JSONDecoder().decode(HelperReply.self, from: data), let err = reply.error {
            throw reply.code == "untrusted" ? HelperError.untrusted : HelperError.failed(code: reply.code ?? "internal", detail: err)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw HelperError.failed(code: "unexpected", detail: String(text.prefix(300)))
        }
    }

    private static func exec(_ tool: String, _ args: [String], timeout: TimeInterval) async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: tool)
                p.arguments = args
                let out = Pipe(), err = Pipe()
                p.standardOutput = out
                p.standardError = err
                do {
                    try p.run()
                } catch {
                    cont.resume(throwing: error)
                    return
                }
                let killer = DispatchWorkItem { if p.isRunning { p.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)

                // Beide Pipes gleichzeitig leeren, sonst blockiert ein voller stderr-Puffer alles.
                var errData = Data()
                let group = DispatchGroup()
                group.enter()
                DispatchQueue.global().async {
                    errData = err.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }
                let data = out.fileHandleForReading.readDataToEndOfFile()
                group.wait()
                p.waitUntilExit()
                killer.cancel()

                if p.terminationReason == .uncaughtSignal {
                    cont.resume(throwing: HelperError.failed(code: "timeout"))
                    return
                }
                if data.isEmpty, p.terminationStatus != 0 {
                    let msg = String(data: errData, encoding: .utf8) ?? ""
                    if msg.contains("password is required") || msg.contains("Passwort") {
                        cont.resume(throwing: HelperError.notInstalled)
                    } else {
                        cont.resume(throwing: HelperError.failed(code: "internal", detail: msg.trimmingCharacters(in: .whitespacesAndNewlines)))
                    }
                    return
                }
                cont.resume(returning: data)
            }
        }
    }

    /// Installiert Helfer und sudoers-Regel. macOS fragt dabei einmal nach dem Passwort.
    static func install() async throws {
        guard let script = Bundle.main.path(forResource: "install-helper", ofType: "sh"),
              let helper = Bundle.main.path(forResource: "mountbar-helper", ofType: nil) else {
            throw HelperError.failed(code: "setup_files")
        }
        let user = NSUserName()
        let cmd = "/bin/bash \(shellQuote(script)) \(shellQuote(helper)) \(shellQuote(user))"
        let source = "do shell script \"\(cmd.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.main.async {
                var error: NSDictionary?
                NSAppleScript(source: source)?.executeAndReturnError(&error)
                if let error {
                    let number = error[NSAppleScript.errorNumber] as? Int
                    let msg = error[NSAppleScript.errorMessage] as? String ?? ""
                    cont.resume(throwing: number == -128
                                 ? HelperError.failed(code: "setup_cancelled")
                                 : HelperError.failed(code: "internal", detail: msg))
                } else {
                    cont.resume()
                }
            }
        }
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
