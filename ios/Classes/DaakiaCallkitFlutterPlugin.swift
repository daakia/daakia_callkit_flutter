import CallKit
import Flutter
import PushKit
import UIKit

public class DaakiaCallkitFlutterPlugin: NSObject, FlutterPlugin, PKPushRegistryDelegate, CXProviderDelegate {
  private static let channelName = "daakia_callkit_flutter/voip"
  private static let fallbackBaseUrlKey = "daakia_callkit_fallback_base_url"
  private static let fallbackSecretKey = "daakia_callkit_fallback_secret"
  private static let fallbackActionsKey = "daakia_callkit_fallback_actions"
  private static let fallbackMetadataKey = "daakia_callkit_fallback_metadata"
  private static let sentEventsKey = "daakia_callkit_sent_events"
  private static let fallbackDispatchDelay: TimeInterval = 1.5

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
    case "configureCallEventFallback":
      if let args = call.arguments as? [String: Any] {
        configureCallEventFallback(args)
      }
      result(nil)
    case "clearCallEventFallback":
      clearCallEventFallback()
      result(nil)
    case "wasCallEventSent":
      if
        let args = call.arguments as? [String: Any],
        let meetingUid = args["meetingUid"] as? String,
        let action = args["action"] as? String
      {
        result(wasCallEventSent(meetingUid: meetingUid, action: action))
      } else {
        result(false)
      }
    case "markCallEventSent":
      if
        let args = call.arguments as? [String: Any],
        let meetingUid = args["meetingUid"] as? String,
        let action = args["action"] as? String
      {
        markCallEventSent(meetingUid: meetingUid, action: action)
      }
      result(nil)
    case "clearSentCallEventCache":
      clearSentCallEventCache()
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

  private func configureCallEventFallback(_ args: [String: Any]) {
    UserDefaults.standard.set(args["baseUrl"] as? String, forKey: Self.fallbackBaseUrlKey)
    UserDefaults.standard.set(args["secret"] as? String, forKey: Self.fallbackSecretKey)
    UserDefaults.standard.set(args["actions"] as? [String] ?? [], forKey: Self.fallbackActionsKey)
    UserDefaults.standard.set(args["metadata"] as? [String: Any] ?? [:], forKey: Self.fallbackMetadataKey)
  }

  private func clearCallEventFallback() {
    UserDefaults.standard.removeObject(forKey: Self.fallbackBaseUrlKey)
    UserDefaults.standard.removeObject(forKey: Self.fallbackSecretKey)
    UserDefaults.standard.removeObject(forKey: Self.fallbackActionsKey)
    UserDefaults.standard.removeObject(forKey: Self.fallbackMetadataKey)
  }

  private func wasCallEventSent(meetingUid: String, action: String) -> Bool {
    let sentEvents = UserDefaults.standard.array(forKey: Self.sentEventsKey) as? [String] ?? []
    return sentEvents.contains("\(meetingUid)::\(action)")
  }

  private func markCallEventSent(meetingUid: String, action: String) {
    var sentEvents = UserDefaults.standard.array(forKey: Self.sentEventsKey) as? [String] ?? []
    let key = "\(meetingUid)::\(action)"
    if sentEvents.contains(key) {
      return
    }
    sentEvents.append(key)
    if sentEvents.count > 100 {
      sentEvents = Array(sentEvents.suffix(100))
    }
    UserDefaults.standard.set(sentEvents, forKey: Self.sentEventsKey)
  }

  private func clearSentCallEventCache() {
    UserDefaults.standard.removeObject(forKey: Self.sentEventsKey)
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

  private func fallbackActions() -> [String] {
    UserDefaults.standard.array(forKey: Self.fallbackActionsKey) as? [String] ?? []
  }

  private func fallbackMetadata() -> [String: Any] {
    UserDefaults.standard.dictionary(forKey: Self.fallbackMetadataKey) ?? [:]
  }

  private func sendFallbackWebhookIfEnabled(callId: String, action: String, payload: [String: Any]) {
    let baseUrl = UserDefaults.standard.string(forKey: Self.fallbackBaseUrlKey) ?? ""
    let secret = UserDefaults.standard.string(forKey: Self.fallbackSecretKey) ?? ""
    guard !baseUrl.isEmpty, !secret.isEmpty else { return }
    guard fallbackActions().contains(action) else { return }
    guard !wasCallEventSent(meetingUid: callId, action: action) else { return }

    let sanitizedBaseUrl = baseUrl.hasSuffix("/") ? String(baseUrl.dropLast()) : baseUrl
    guard let url = URL(string: "\(sanitizedBaseUrl)/v2.0/rtc/call/webhook") else {
      return
    }

    var metadata = fallbackMetadata()
    if let callerId = payload["callerId"] as? String, !callerId.isEmpty {
      metadata["caller_id"] = callerId
    }
    if let receiverId = payload["receiverId"] as? String, !receiverId.isEmpty {
      metadata["receiver_id"] = receiverId
    }
    if let callTimestamp = payload["callTimestamp"] as? String, !callTimestamp.isEmpty {
      metadata["call_timestamp"] = callTimestamp
    }
    metadata["delivery_mode"] = "fallback"
    metadata["platform"] = "ios"

    let body: [String: Any] = [
      "meeting_uid": callId,
      "data": [
        "action": action,
        "meta-data": metadata,
      ],
    ]

    guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = bodyData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(secret, forHTTPHeaderField: "secret")

    DispatchQueue.global(qos: .utility).asyncAfter(
      deadline: .now() + Self.fallbackDispatchDelay
    ) { [weak self] in
      guard let self else { return }
      guard !self.wasCallEventSent(meetingUid: callId, action: action) else { return }

      URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
        guard
          let self,
          let httpResponse = response as? HTTPURLResponse,
          (200..<300).contains(httpResponse.statusCode),
          let data,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          (json["success"] as? Int) == 1
        else { return }
        self.markCallEventSent(meetingUid: callId, action: action)
      }.resume()
    }
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

    sendFallbackWebhookIfEnabled(
      callId: callId,
      action: "call-accept",
      payload: payloadForCallId(callId)
    )
    enqueueEvent("callAccepted", arguments: payloadForCallId(callId))
    action.fulfill()
  }

  public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    guard let callId = callUUIDs.first(where: { $0.value == action.callUUID })?.key else {
      action.fulfill()
      return
    }

    sendFallbackWebhookIfEnabled(
      callId: callId,
      action: "call-reject",
      payload: payloadForCallId(callId)
    )
    enqueueEvent("callDeclined", arguments: payloadForCallId(callId))
    endCall(callId: callId, reason: .remoteEnded, notifyFlutter: false)
    action.fulfill()
  }
}
