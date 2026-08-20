import AppKit
import LocalAuthentication

// MARK: - Keys Menu

extension VPhoneMenuController {
    func buildKeysMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Keys")
        menu.addItem(makeItem("Home Screen", action: #selector(sendHome)))
        menu.addItem(makeItem("Power", action: #selector(sendPower)))
        menu.addItem(makeItem("Volume Up", action: #selector(sendVolumeUp)))
        menu.addItem(makeItem("Volume Down", action: #selector(sendVolumeDown)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeItem("Spotlight (Cmd+Space)", action: #selector(sendSpotlight)))
        menu.addItem(NSMenuItem.separator())

        let orientationItem = NSMenuItem()
        let orientationMenu = NSMenu(title: "Orientation")
        orientationMenu.addItem(makeItem("Portrait", action: #selector(orientPortrait)))
        orientationMenu.addItem(makeItem("Portrait Upside Down", action: #selector(orientPortraitUpsideDown)))
        orientationMenu.addItem(makeItem("Landscape Left", action: #selector(orientLandscapeLeft)))
        orientationMenu.addItem(makeItem("Landscape Right", action: #selector(orientLandscapeRight)))
        orientationItem.title = "Orientation"
        orientationItem.submenu = orientationMenu
        menu.addItem(orientationItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeItem("Type ASCII from Clipboard", action: #selector(typeFromClipboard)))
        menu.addItem(NSMenuItem.separator())
        let tidItem = makeItem("Touch ID Home Forwarding", action: #selector(toggleTouchIDForwarding))
        if hasTouchID {
            let tidEnabled = !UserDefaults.standard.bool(forKey: "touchIDForwardingDisabled")
            tidItem.state = tidEnabled ? .on : .off
        } else {
            tidItem.isEnabled = false
            tidItem.state = .off
        }
        touchIDMenuItem = tidItem
        menu.addItem(tidItem)
        item.submenu = menu
        return item
    }

    @objc func sendHome() {
        keyHelper.sendHome()
    }

    @objc func sendPower() {
        keyHelper.sendPower()
    }

    @objc func sendVolumeUp() {
        keyHelper.sendVolumeUp()
    }

    @objc func sendVolumeDown() {
        keyHelper.sendVolumeDown()
    }

    @objc func sendSpotlight() {
        keyHelper.sendSpotlight()
    }

    @objc func orientPortrait() {
        keyHelper.sendOrientation(.portrait)
    }

    @objc func orientPortraitUpsideDown() {
        keyHelper.sendOrientation(.portraitUpsideDown)
    }

    @objc func orientLandscapeLeft() {
        keyHelper.sendOrientation(.landscapeLeft)
    }

    @objc func orientLandscapeRight() {
        keyHelper.sendOrientation(.landscapeRight)
    }

    @objc func typeFromClipboard() {
        keyHelper.typeFromClipboard()
    }

    @objc func toggleTouchIDForwarding() {
        guard let monitor = touchIDMonitor, let item = touchIDMenuItem else { return }
        monitor.isEnabled.toggle()
        item.state = monitor.isEnabled ? .on : .off
        UserDefaults.standard.set(!monitor.isEnabled, forKey: "touchIDForwardingDisabled")
    }
}

private extension VPhoneMenuController {
    var hasTouchID: Bool {
        let ctx = LAContext()
        ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType == .touchID
    }
}
