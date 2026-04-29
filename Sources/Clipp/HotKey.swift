import AppKit
import Carbon.HIToolbox

final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let handler: () -> Void
    private static var registry: [UInt32: HotKey] = [:]
    private static var nextID: UInt32 = 1

    init(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.handler = handler
        let id = HotKey.nextID
        HotKey.nextID += 1
        HotKey.registry[id] = self

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hkID)
            if let hk = HotKey.registry[hkID.id] {
                DispatchQueue.main.async { hk.handler() }
            }
            return noErr
        }, 1, &eventType, nil, &handlerRef)

        let hkID = EventHotKeyID(signature: OSType(0x4B4B5348), id: id) // 'KKSH'
        RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = handlerRef { RemoveEventHandler(ref) }
    }
}
