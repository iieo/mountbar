import Foundation

enum HelperError: LocalizedError {
    case notInstalled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled: return "Der Helfer ist noch nicht eingerichtet."
        case .failed(let msg): return msg
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

    static func run<T: Decodable>(_ args: [String], as type: T.Type) async throws -> T {
        guard FileManager.default.isExecutableFile(atPath: path) else { throw HelperError.notInstalled }
        let data = try await exec("/usr/bin/sudo", ["-n", path] + args)
        if let reply = try? JSONDecoder().decode(HelperReply.self, from: data), let err = reply.error {
            throw HelperError.failed(err)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw HelperError.failed(text.isEmpty ? "Unerwartete Antwort vom Helfer" : text)
        }
    }

    private static func exec(_ tool: String, _ args: [String]) async throws -> Data {
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
                let data = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                if data.isEmpty, p.terminationStatus != 0 {
                    let msg = String(data: errData, encoding: .utf8) ?? ""
                    if msg.contains("password is required") || msg.contains("Passwort") {
                        cont.resume(throwing: HelperError.notInstalled)
                    } else {
                        cont.resume(throwing: HelperError.failed(msg.trimmingCharacters(in: .whitespacesAndNewlines)))
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
            throw HelperError.failed("Installationsdateien fehlen im App-Bundle")
        }
        let user = NSUserName()
        let cmd = "/bin/bash \(shellQuote(script)) \(shellQuote(helper)) \(shellQuote(user))"
        let source = "do shell script \"\(cmd.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.main.async {
                var error: NSDictionary?
                NSAppleScript(source: source)?.executeAndReturnError(&error)
                if let error {
                    let msg = error[NSAppleScript.errorMessage] as? String ?? "Einrichtung abgebrochen"
                    cont.resume(throwing: HelperError.failed(msg))
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
