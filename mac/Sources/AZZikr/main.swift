import AppKit

let args = CommandLine.arguments

if let i = args.firstIndex(of: "--make-icon"), args.count > i + 1 {
    _ = NSApplication.shared
    MainActor.assumeIsolated { AZBrand.writeAppIcon(to: URL(fileURLWithPath: args[i + 1])) }
    exit(0)
}

if let i = args.firstIndex(of: "--export-ico"), args.count > i + 3 {
    _ = NSApplication.shared
    MainActor.assumeIsolated {
        IconExport.run(appICO: URL(fileURLWithPath: args[i + 1]), trayICO: URL(fileURLWithPath: args[i + 2]),
                       appPNG: URL(fileURLWithPath: args[i + 3]))
    }
    exit(0)
}

if let i = args.firstIndex(of: "--snapshot"), args.count > i + 1 {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    MainActor.assumeIsolated { Snapshots.run(to: URL(fileURLWithPath: args[i + 1])) }
    app.run()
}

let app = NSApplication.shared
MainActor.assumeIsolated {
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
