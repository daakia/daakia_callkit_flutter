import CallKit
import Flutter
import PushKit
import UIKit

public class DaakiaCallkitFlutterPlugin: NSObject, FlutterPlugin, PKPushRegistryDelegate, CXProviderDelegate {
  private static let channelName = "daakia_callkit_flutter/voip"

  private var voipRegistry: PKPushRegistry?
  private var voipToken: String?
  private var flutterChannel: FlutterMethodChannel?
  private var pendingEvents: [(String, Any?)] = []
  private var callPayloads: [String: [String: Any]] = [:]
  private var callUUIDs: [String: UUID] = [:]

  private lazy var callProvider: CXProvider = {
    let appName =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
      Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ??
      "Daakia"

    let configuration = CXProviderConfiguration(localizedName: appName)
    configuration.supportsVideo = true
    configuration.maximumCallsPerCallGroup = 1
    configuration.maximumCallGroups = 1
    configuration.supportedHandleTypes = [.generic]
    configuration.includesCallsInRecents = false

    let provider = CXProvider(configuration: configuration)
    provider.setDelegate(self, queue: nil)
    return provider
  }()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = DaakiaCallkitFlutterPlugin()
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    instance.flutterChannel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
    instance.configureVoipRegistry()
    instance.flushPendingEvents()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "register":
      flushPendingEvents()
      result(nil)
    case "getVoipToken":
      result(voipToken)
    case "endCall":
      if
        let args = call.arguments as? [String: Any],
        let callId = args["callId"] as? String
      {
        endCall(callId: callId, reason: .remoteEnded, notifyFlutter: false)
      }
      result(nil)
    case "setCallConnected":
      if
        let args = call.arguments as? [String: Any],
        let callId = args["callId"] as? String
      {
        setCallConnected(callId: callId)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func configureVoipRegistry() {
    if voipRegistry != nil {
      return
    }

    let registry = PKPushRegistry(queue: DispatchQueue.main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry
  }

  private func enqueueEvent(_ method: String, arguments: Any?) {
    guard let channel = flutterChannel else {
      pendingEvents.append((method, arguments))
      return
    }

    channel.invokeMethod(method, arguments: arguments)
  }

  private func flushPendingEvents() {
    guard let channel = flutterChannel else {
      return
    }

    let events = pendingEvents
    pendingEvents.removeAll()
    for event in events {
      channel.invokeMethod(event.0, arguments: event.1)
    }
  }

  private func normalizePayload(_ payload: [AnyHashable: Any]) -> [String: Any] {
    var normalized: [String: Any] = [:]

    for (key, value) in payload {
      guard let keyString = key as? String else { continue }
      if keyString == "aps" { continue }
      normalized[keyString] = value
    }

    if let nested = normalized["payload"] as? [String: Any] {
      normalized.merge(nested) { current, _ in current }
    }

    if normalized["type"] == nil {
      normalized["type"] = "incoming_call"
    }

    if normalized["callerName"] == nil {
      if let sender = normalized["sender"] as? String,
         let data = sender.data(using: .utf8),
         let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let senderName = object["userName"] as? String {
        normalized["callerName"] = senderName
      } else if let sender = normalized["sender"] as? [String: Any],
                let senderName = sender["userName"] as? String {
        normalized["callerName"] = senderName
      }
    }

    return normalized
  }

  private func payloadForCallId(_ callId: String) -> [String: Any] {
    callPayloads[callId] ?? ["callId": callId, "type": "incoming_call"]
  }

  private func reportIncomingCall(payload: [String: Any], completion: (() -> Void)? = nil) {
    guard let callId = payload["callId"] as? String, !callId.isEmpty else {
      enqueueEvent("incomingCall", arguments: payload)
      completion?()
      return
    }

    let uuid = callUUIDs[callId] ?? UUID()
    callUUIDs[callId] = uuid
    callPayloads[callId] = payload

    let update = CXCallUpdate()
    let callerName = (payload["callerName"] as? String) ??
      (payload["title"] as? String) ??
      "Incoming Call"
    update.localizedCallerName = callerName
    update.remoteHandle = CXHandle(type: .generic, value: callerName)
    update.hasVideo = true
    update.supportsHolding = false
    update.supportsGrouping = false
    update.supportsUngrouping = false
    update.supportsDTMF = false

    callProvider.reportNewIncomingCall(with: uuid, update: update) { [weak self] _ in
      self?.enqueueEvent("incomingCall", arguments: payload)
      completion?()
    }
  }

  private func endCall(callId: String, reason: CXCallEndedReason, notifyFlutter: Bool) {
    guard let uuid = callUUIDs[callId] else {
      return
    }

    if notifyFlutter {
      enqueueEvent("callEnded", arguments: payloadForCallId(callId))
    }

    callProvider.reportCall(with: uuid, endedAt: Date(), reason: reason)
    callUUIDs.removeValue(forKey: callId)
    callPayloads.removeValue(forKey: callId)
  }

  private func setCallConnected(callId: String) {
    guard callUUIDs[callId] != nil else {
      return
    }
  }

  public func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate pushCredentials: PKPushCredentials,
    for type: PKPushType
  ) {
    guard type == .voIP else { return }
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    voipToken = token
    enqueueEvent("voipTokenUpdated", arguments: token)
  }

  public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    guard type == .voIP else { return }
    voipToken = nil
    enqueueEvent("voipTokenUpdated", arguments: "")
  }

  public func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else {
      completion()
      return
    }

    let normalizedPayload = normalizePayload(payload.dictionaryPayload)
    reportIncomingCall(payload: normalizedPayload, completion: completion)
  }

  public func providerDidReset(_ provider: CXProvider) {
    callUUIDs.removeAll()
    callPayloads.removeAll()
  }

  public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    guard let callId = callUUIDs.first(where: { $0.value == action.callUUID })?.key else {
      action.fulfill()
      return
    }

    enqueueEvent("callAccepted", arguments: payloadForCallId(callId))
    action.fulfill()
  }

  public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    guard let callId = callUUIDs.first(where: { $0.value == action.callUUID })?.key else {
      action.fulfill()
      return
    }

    enqueueEvent("callDeclined", arguments: payloadForCallId(callId))
    endCall(callId: callId, reason: .remoteEnded, notifyFlutter: false)
    action.fulfill()
  }
}
