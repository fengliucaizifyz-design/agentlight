import AppKit
import Foundation
import Network

// ============================================================================
// AgentLight Hub
//
// A macOS menu-bar status light that reflects the live state of AI coding
// agents (Claude Code / Codex / OpenClaw). Agents POST their state to a local
// HTTP server; the hub renders it in the menu bar and (optionally) drives a
// WLED physical light over the LAN.
//
// See docs/DESIGN.md for the full design.
// ============================================================================

// MARK: - Configuration

let PORT: UInt16 = 9527

let home = FileManager.default.homeDirectoryForCurrentUser
let configDir = home.appendingPathComponent(".agentlight")
let configURL = configDir.appendingPathComponent("config.json")
let logURL = home.appendingPathComponent("Library/Logs/AgentLight.log")

func log(_ msg: String) {
    let line = "[AgentLight] \(msg)\n"
    guard let data = line.data(using: .utf8) else { return }
    if let handle = try? FileHandle(forWritingTo: logURL) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    } else {
        try? FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: logURL, options: .atomic)
    }
    fputs(line, stderr)
}

// MARK: - State model

/// One of the five canonical states. `rgb` is consumed by the WLED output.
struct StateStyle {
    let emoji: String
    let label: String
    let rgb: (Int, Int, Int)
}

let STATES: [String: StateStyle] = [
    "idle":    StateStyle(emoji: "🟢", label: "Idle",    rgb: (0, 200, 0)),
    "working": StateStyle(emoji: "🟡", label: "Working", rgb: (255, 180, 0)),
    "confirm": StateStyle(emoji: "🔵", label: "Confirm", rgb: (0, 120, 255)),
    "error":   StateStyle(emoji: "🔴", label: "Error",   rgb: (255, 0, 0)),
    "offline": StateStyle(emoji: "⚪️", label: "Offline", rgb: (0, 0, 0)),
]

/// Pretty display name per agent source.
let SOURCE_NAMES: [String: String] = [
    "claude-code": "Claude",
    "codex": "Codex",
    "openclaw": "OpenClaw",
]

func displayName(forSource source: String?) -> String {
    guard let source = source, !source.isEmpty else { return "Agent" }
    return SOURCE_NAMES[source] ?? source.capitalized
}

// MARK: - Config file (WLED IP etc.)

struct AppConfig {
    var wledIP: String?

    static func load() -> AppConfig {
        guard let data = try? Data(contentsOf: configURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return AppConfig(wledIP: nil) }
        let ip = (obj["wledIP"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return AppConfig(wledIP: ip)
    }

    func save() {
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        let obj: [String: Any] = ["wledIP": wledIP ?? ""]
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted) {
            try? data.write(to: configURL, options: .atomic)
        }
    }
}

// MARK: - WLED output

enum WLED {
    /// Push a solid color to a WLED device over the LAN. Failures are non-fatal.
    static func push(ip: String, rgb: (Int, Int, Int)) {
        guard let url = URL(string: "http://\(ip)/json/state") else { return }
        let on = !(rgb.0 == 0 && rgb.1 == 0 && rgb.2 == 0)
        let body: [String: Any] = [
            "on": on,
            "bri": 160,
            "seg": [["col": [[rgb.0, rgb.1, rgb.2]]]],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        req.timeoutInterval = 2
        URLSession.shared.dataTask(with: req) { _, _, err in
            if let err = err { log("WLED push failed: \(err.localizedDescription)") }
        }.resume()
    }
}

// MARK: - App Delegate (menu bar)

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var config = AppConfig.load()

    // Current rendered state
    var currentState = "offline"
    var currentSource: String? = nil
    var currentDetail: String? = nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true

        let menu = NSMenu()
        // First line shows the full status (agent + state + detail); updated in render().
        let statusLine = NSMenuItem(title: "AgentLight", action: nil, keyEquivalent: "")
        statusLine.tag = 88
        menu.addItem(statusLine)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Set Physical Light (WLED) IP…",
                                action: #selector(setWledIP), keyEquivalent: ""))
        let wledStatus = NSMenuItem(
            title: config.wledIP.map { "WLED: \($0)" } ?? "WLED: not set",
            action: nil, keyEquivalent: "")
        wledStatus.tag = 99
        menu.addItem(wledStatus)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu

        render()

        // Start the HTTP hub
        HTTPServer.shared.onState = { [weak self] state, source, detail in
            DispatchQueue.main.async { self?.apply(state: state, source: source, detail: detail) }
        }
        HTTPServer.shared.stateProvider = { [weak self] in
            (self?.currentState ?? "offline", self?.currentSource, self?.currentDetail)
        }
        HTTPServer.shared.start()
        log("AgentLight started on port \(PORT)")
    }

    func apply(state: String, source: String?, detail: String?) {
        guard STATES[state] != nil else { log("ignored unknown state: \(state)"); return }
        currentState = state
        currentSource = source
        currentDetail = detail
        render()
        if let ip = config.wledIP, let style = STATES[state] {
            WLED.push(ip: ip, rgb: style.rgb)
        }
        log("state → \(displayName(forSource: source)) \(state)\(detail.map { " (\($0))" } ?? "")")
    }

    func render() {
        let style = STATES[currentState] ?? STATES["offline"]!
        let name = displayName(forSource: currentSource)
        // Menu bar: just the colored dot — compact so it never overflows a busy /
        // notched menu bar. Full status lives in the tooltip and the dropdown.
        statusItem.button?.title = style.emoji
        var full = "\(name) \(style.emoji) \(style.label)"
        if let d = currentDetail, !d.isEmpty { full += " — \(d)" }
        statusItem.button?.toolTip = full
        statusItem.menu?.item(withTag: 88)?.title = full
    }

    @objc func setWledIP() {
        let alert = NSAlert()
        alert.messageText = "Physical Light (WLED) IP"
        alert.informativeText = "Enter the LAN IP of your WLED light (leave empty to disable). Example: 192.168.1.42"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = config.wledIP ?? ""
        alert.accessoryView = field
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let ip = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            config.wledIP = ip.isEmpty ? nil : ip
            config.save()
            if let item = statusItem.menu?.item(withTag: 99) {
                item.title = config.wledIP.map { "WLED: \($0)" } ?? "WLED: not set"
            }
            log("WLED IP set to \(config.wledIP ?? "(none)")")
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}

// MARK: - HTTP server (Network framework)

final class HTTPServer {
    static let shared = HTTPServer()

    var onState: ((String, String?, String?) -> Void)?
    var stateProvider: (() -> (String, String?, String?))?

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "agentlight.http")

    func start() {
        ensurePortFree()
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: PORT)!)
        } catch {
            log("failed to create listener: \(error)")
            return
        }
        listener?.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }
        listener?.start(queue: queue)
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        receive(conn, buffer: Data())
    }

    private func receive(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            var buffer = buffer
            if let data = data { buffer.append(data) }

            if let request = self.parseIfComplete(buffer) {
                self.respond(conn, to: request)
                return
            }
            if isComplete || error != nil {
                conn.cancel()
                return
            }
            self.receive(conn, buffer: buffer)
        }
    }

    private struct Request {
        let method: String
        let path: String
        let body: Data
    }

    /// Returns a parsed Request once headers (and any Content-Length body) are fully received.
    private func parseIfComplete(_ buffer: Data) -> Request? {
        guard let headerRange = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = buffer.subdata(in: buffer.startIndex..<headerRange.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return nil }
        let method = parts[0]
        let path = parts[1]

        var contentLength = 0
        for line in lines.dropFirst() {
            let kv = line.components(separatedBy: ":")
            if kv.count >= 2, kv[0].lowercased() == "content-length" {
                contentLength = Int(kv[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }

        let bodyStart = headerRange.upperBound
        let available = buffer.distance(from: bodyStart, to: buffer.endIndex)
        if available < contentLength { return nil }  // wait for full body
        let body = buffer.subdata(in: bodyStart..<buffer.index(bodyStart, offsetBy: contentLength))
        return Request(method: method, path: path, body: body)
    }

    private func respond(_ conn: NWConnection, to req: Request) {
        let pathOnly = req.path.components(separatedBy: "?").first ?? req.path

        if req.method == "POST", pathOnly == "/state" {
            if let obj = try? JSONSerialization.jsonObject(with: req.body) as? [String: Any],
               let state = obj["state"] as? String, STATES[state] != nil {
                let source = obj["source"] as? String
                let detail = obj["detail"] as? String
                onState?(state, source, detail)
                send(conn, status: "200 OK", json: "{\"ok\":true}")
            } else {
                send(conn, status: "400 Bad Request",
                     json: "{\"ok\":false,\"error\":\"missing or unknown state\"}")
            }
            return
        }

        if req.method == "GET", pathOnly == "/state" {
            let (state, source, detail) = stateProvider?() ?? ("offline", nil, nil)
            let payload: [String: Any] = [
                "state": state,
                "source": source ?? NSNull(),
                "detail": detail ?? NSNull(),
            ]
            let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data("{}".utf8)
            send(conn, status: "200 OK", json: String(data: data, encoding: .utf8) ?? "{}")
            return
        }

        if req.method == "OPTIONS" {
            send(conn, status: "204 No Content", json: "")
            return
        }

        send(conn, status: "404 Not Found", json: "{\"ok\":false}")
    }

    private func send(_ conn: NWConnection, status: String, json: String) {
        let body = Data(json.utf8)
        let headers = [
            "HTTP/1.1 \(status)",
            "Content-Type: application/json",
            "Content-Length: \(body.count)",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS",
            "Access-Control-Allow-Headers: Content-Type",
            "Connection: close",
            "", "",
        ].joined(separator: "\r\n")
        var out = Data(headers.utf8)
        out.append(body)
        conn.send(content: out, completion: .contentProcessed { _ in conn.cancel() })
    }

    /// Kill any stale instance holding the port (e.g. a previous run).
    private func ensurePortFree() {
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-t", "-i:\(PORT)"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        guard let data = try? pipe.fileHandleForReading.readToEnd(),
              let text = String(data: data, encoding: .utf8) else { return }
        let myPid = ProcessInfo.processInfo.processIdentifier
        for line in text.split(separator: "\n") {
            if let pid = Int32(line.trimmingCharacters(in: .whitespaces)), pid != myPid {
                log("port \(PORT) held by PID \(pid), killing…")
                kill(pid, SIGKILL)
            }
        }
        Thread.sleep(forTimeInterval: 0.3)
    }
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // menu-bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
