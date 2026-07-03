import CoreGraphics
import Foundation

final class EventTap {
    private let controller: InputController
    private let synthesizer: KeySynthesizer
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(controller: InputController, synthesizer: KeySynthesizer) {
        self.controller = controller
        self.synthesizer = synthesizer
    }

    /// Returns false if the tap could not be created (usually: Accessibility not granted).
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }   // already running
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else { return false }
        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        tap = nil; runLoopSource = nil
    }

    func reEnable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    /// Called by the C callback. Returns the (possibly nil) event to forward.
    func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Auto-recovery: macOS disabled the tap (slow callback / too many keys).
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            reEnable()
            return Unmanaged.passUnretained(event)
        }
        // Skip our own synthesized events.
        if event.getIntegerValueField(.eventSourceStateID) == synthesizer.sourceStateID {
            return Unmanaged.passUnretained(event)
        }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let caps = flags.contains(.maskShift) || flags.contains(.maskAlphaShift)
        let hasOtherControl = flags.contains(.maskControl) || flags.contains(.maskCommand)
            || flags.contains(.maskAlternate) || flags.contains(.maskSecondaryFn)
            || flags.contains(.maskNumericPad) || flags.contains(.maskHelp)
        let kind: KeyEvent.Kind = type == .keyDown ? .keyDown
            : (type == .keyUp ? .keyUp : .flagsChanged)
        let ke = KeyEvent(keyCode: keyCode, caps: caps, hasOtherControl: hasOtherControl,
                          kind: kind, flags: flags.rawValue)

        switch controller.handle(ke) {
        case .passthrough:
            return Unmanaged.passUnretained(event)
        case .toggleLanguage:
            return nil                               // consume ⌥Z (state already flipped)
        case .consume(let backspaces, let chars):
            synthesizer.sendBackspaces(backspaces, proxy: proxy)
            synthesizer.sendUnicode(chars, proxy: proxy)
            return nil                               // swallow the original key
        }
    }
}

/// Top-level C callback: unwrap refcon → EventTap.
private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType,
                              event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
    return tap.handle(proxy: proxy, type: type, event: event)
}
