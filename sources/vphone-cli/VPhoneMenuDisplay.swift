import AppKit

// MARK: - Display Menu

extension VPhoneMenuController {
    func buildDisplayMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Display")
        menu.addItem(makeItem("Rotate Left", action: #selector(rotateDisplayLeft)))
        menu.addItem(makeItem("Rotate Right", action: #selector(rotateDisplayRight)))
        menu.addItem(makeItem("Rotate 180°", action: #selector(rotateDisplay180)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeItem("Reset Rotation", action: #selector(resetDisplayRotation)))
        item.title = "Display"
        item.submenu = menu
        return item
    }

    @objc func rotateDisplayLeft() {
        captureView?.rotateDisplay(byDegrees: 90)
    }

    @objc func rotateDisplayRight() {
        captureView?.rotateDisplay(byDegrees: 270)
    }

    @objc func rotateDisplay180() {
        captureView?.rotateDisplay(byDegrees: 180)
    }

    @objc func resetDisplayRotation() {
        captureView?.setDisplayRotation(0)
    }
}
