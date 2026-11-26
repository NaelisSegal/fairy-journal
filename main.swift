// Fairy Journal: a tiny Mac journal in the PinkFairy style.
// Pages live in ~/Documents/Journal as one file per day
// (2026-11-26.html). A day with nothing written is never saved.

import Cocoa
import WebKit

let env = ProcessInfo.processInfo.environment
// FJ_DIR / FJ_TEST are only for testing the app.
let journalDir = env["FJ_DIR"].map { URL(fileURLWithPath: $0) }
    ?? FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Documents/Journal", isDirectory: true)

func isDateKey(_ s: String) -> Bool {
    return s.range(of: #"^\d{4}-\d{2}-\d{2}$"#,
                   options: .regularExpression) != nil
}

func fileFor(_ date: String) -> URL {
    return journalDir.appendingPathComponent("\(date).html")
}

func writePage(_ date: String, _ html: String) {
    guard isDateKey(date) else { return }
    try? FileManager.default.createDirectory(
        at: journalDir, withIntermediateDirectories: true)
    try? html.write(to: fileFor(date), atomically: true,
                    encoding: .utf8)
}

func deletePage(_ date: String) {
    guard isDateKey(date) else { return }
    try? FileManager.default.removeItem(at: fileFor(date))
}

func allPages() -> [[String: String]] {
    let fm = FileManager.default
    guard let names = try? fm.contentsOfDirectory(
        atPath: journalDir.path) else { return [] }
    var out: [[String: String]] = []
    for n in names where n.hasSuffix(".html") {
        let d = String(n.dropLast(5))
        guard isDateKey(d) else { continue }
        let html = (try? String(contentsOf: fileFor(d),
                                encoding: .utf8)) ?? ""
        out.append(["date": d, "html": html])
    }
    return out.sorted { $0["date"]! > $1["date"]! }
}

class AppDelegate: NSObject, NSApplicationDelegate,
                   WKScriptMessageHandlerWithReply,
                   WKNavigationDelegate {
    var window: NSWindow!
    var web: WKWebView!

    func applicationDidFinishLaunching(_ n: Notification) {
        // Autocorrect + spell check on by default (the
        // Edit > Spelling menu can still switch them off).
        UserDefaults.standard.register(defaults: [
            "WebContinuousSpellCheckingEnabled": true,
            "WebAutomaticSpellingCorrectionEnabled": true,
            "WebAutomaticTextReplacementEnabled": true,
            "WebGrammarCheckingEnabled": false,
        ])
        buildMenu()

        let cfg = WKWebViewConfiguration()
        cfg.userContentController.addScriptMessageHandler(
            self, contentWorld: .page, name: "journal")
        web = WKWebView(frame: .zero, configuration: cfg)
        web.setValue(false, forKey: "drawsBackground")
        web.navigationDelegate = self

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 780),
            styleMask: [.titled, .closable, .miniaturizable,
                        .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "Fairy Journal"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 400)
        window.backgroundColor = .white
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = web
        window.center()
        window.setFrameAutosaveName("FairyJournalWindow")

        let page = Bundle.main.url(forResource: "index",
                                   withExtension: "html")!
        web.loadFileURL(page, allowingReadAccessTo:
                        page.deletingLastPathComponent())
        if env["FJ_TEST"] == nil {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // tests must not take the keyboard from the user
            window.orderBack(nil)
        }
    }

    func userContentController(
        _ ucc: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping (Any?, String?) -> Void
    ) {
        guard let m = message.body as? [String: Any],
              let op = m["op"] as? String else {
            replyHandler(nil, "bad message"); return
        }
        switch op {
        case "init":
            let lang = Locale.current.identifier
                .components(separatedBy: "@")[0]
                .replacingOccurrences(of: "_", with: "-")
            replyHandler([
                "firstWeekday": Calendar.current.firstWeekday,
                "locale": lang,
                "pages": allPages(),
            ], nil)
        case "list":
            replyHandler(allPages(), nil)
        case "save":
            let d = m["date"] as? String ?? ""
            writePage(d, m["html"] as? String ?? "")
            replyHandler(true, nil)
        case "delete":
            deletePage(m["date"] as? String ?? "")
            replyHandler(true, nil)
        default:
            replyHandler(nil, "unknown op")
        }
    }

    // Test mode: run steps, snapshot, quit.
    func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
        guard let t = env["FJ_TEST"] else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.runTest(t)
        }
    }

    func runTest(_ dir: String) {
        // type real keys so autocorrect gets a chance
        let typed = Array(env["FJ_TYPE"] ?? "")
        for (i, ch) in typed.enumerated() {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Double(i) * 0.12) {
                let s = String(ch)
                for kind in [NSEvent.EventType.keyDown, .keyUp] {
                    if let e = NSEvent.keyEvent(with: kind,
                        location: .zero, modifierFlags: [],
                        timestamp: ProcessInfo.processInfo
                            .systemUptime,
                        windowNumber: self.window.windowNumber,
                        context: nil, characters: s,
                        charactersIgnoringModifiers: s,
                        isARepeat: false,
                        keyCode: s == " " ? 49 : 0) {
                        self.window.sendEvent(e)
                    }
                }
            }
        }
        let wait = Double(typed.count) * 0.12
        let js = (try? String(contentsOfFile: dir + "/steps.js",
                              encoding: .utf8)) ?? "1"
        DispatchQueue.main.asyncAfter(deadline: .now() + wait + 1.5) {
            self.web.evaluateJavaScript(js) { res, err in
                var states = ""
                if let sp = NSApp.mainMenu?.items.compactMap({
                    $0.submenu?.item(withTitle:
                        "Spelling and Grammar")?.submenu
                }).first {
                    for it in sp.items where it.action != nil {
                        _ = self.web.validateUserInterfaceItem(it)
                        states += "\n\(it.title): \(it.state.rawValue)"
                    }
                }
                let out = "\(res ?? "nil") \(err.map { "\($0)" } ?? "")" + states
                try? out.write(toFile: dir + "/result.txt",
                    atomically: true, encoding: .utf8)
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 1) {
                    self.web.takeSnapshot(with: nil) { img, _ in
                        if let img = img,
                           let t = img.tiffRepresentation,
                           let r = NSBitmapImageRep(data: t),
                           let p = r.representation(
                               using: .png, properties: [:]) {
                            try? p.write(to: URL(fileURLWithPath:
                                dir + "/shot.png"))
                        }
                        NSApp.terminate(nil)
                    }
                }
            }
        }
    }

    // Save whatever is still waiting before quitting.
    func applicationShouldTerminate(_ s: NSApplication)
        -> NSApplication.TerminateReply {
        web.evaluateJavaScript("window.flushNow()") { res, _ in
            if let p = res as? [String: Any],
               let d = p["date"] as? String {
                if p["empty"] as? Bool == true { deletePage(d) }
                else { writePage(d, p["html"] as? String ?? "") }
            }
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ s: NSApplication) -> Bool { return true }

    func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let app = NSMenu()
        app.addItem(withTitle: "About Fairy Journal",
            action: #selector(NSApplication
                .orderFrontStandardAboutPanel(_:)),
            keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Hide Fairy Journal",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h")
        app.addItem(withTitle: "Quit Fairy Journal",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        appItem.submenu = app
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo",
            action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo",
            action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut",
            action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy",
            action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste",
            action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a")
        edit.addItem(.separator())

        let spellItem = NSMenuItem(title: "Spelling and Grammar",
                                   action: nil, keyEquivalent: "")
        let spell = NSMenu(title: "Spelling and Grammar")
        spell.addItem(withTitle: "Show Spelling and Grammar",
            action: #selector(NSText.showGuessPanel(_:)),
            keyEquivalent: ":")
        spell.addItem(withTitle: "Check Document Now",
            action: #selector(NSText.checkSpelling(_:)),
            keyEquivalent: ";")
        spell.addItem(.separator())
        spell.addItem(withTitle: "Check Spelling While Typing",
            action: #selector(NSTextView
                .toggleContinuousSpellChecking(_:)),
            keyEquivalent: "")
        spell.addItem(withTitle: "Correct Spelling Automatically",
            action: #selector(NSTextView
                .toggleAutomaticSpellingCorrection(_:)),
            keyEquivalent: "")
        spellItem.submenu = spell
        edit.addItem(spellItem)
        editItem.submenu = edit
        main.addItem(editItem)

        let winItem = NSMenuItem()
        let win = NSMenu(title: "Window")
        win.addItem(withTitle: "Minimise",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m")
        win.addItem(withTitle: "Close",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w")
        winItem.submenu = win
        main.addItem(winItem)

        NSApp.mainMenu = main
        NSApp.windowsMenu = win
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
