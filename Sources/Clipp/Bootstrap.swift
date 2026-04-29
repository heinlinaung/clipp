import AppKit

@main
@MainActor
struct ClippApp {
    static func main() {
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.run()
        _ = delegate
    }
}
