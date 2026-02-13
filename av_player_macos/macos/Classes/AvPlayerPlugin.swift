import FlutterMacOS
import Foundation
import AVFoundation
import AVKit
import MediaPlayer
import CoreAudio
import IOKit
import IOKit.pwr_mgt

// =============================================================================
// MARK: - Plugin
// =============================================================================

public class AvPlayerPlugin: NSObject, FlutterPlugin {
    private let registrar: FlutterPluginRegistrar
    private let channel: FlutterMethodChannel
    private var players: [Int64: PlayerInstance] = [:]
    private var wakelockAssertionID: IOPMAssertionID = 0

    static let channelName = "com.flutterplaza.av_player_macos"

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        self.channel = FlutterMethodChannel(
            name: Self.channelName,
            binaryMessenger: registrar.messenger
        )
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = AvPlayerPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: instance.channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "create":
            handleCreate(call, result: result)
        case "dispose":
            handleDispose(call, result: result)
        case "play":
            withPlayer(call, result: result) { instance in
                instance.player.play()
                if instance.playbackSpeed != 1.0 {
                    instance.player.rate = instance.playbackSpeed
                }
            }
        case "pause":
            withPlayer(call, result: result) { $0.player.pause() }
        case "seekTo":
            handleSeekTo(call, result: result)
        case "setPlaybackSpeed":
            handleSetPlaybackSpeed(call, result: result)
        case "setLooping":
            handleSetLooping(call, result: result)
        case "setVolume":
            handleSetVolume(call, result: result)
        case "isPipAvailable":
            result(AVPictureInPictureController.isPictureInPictureSupported())
        case "enterPip":
            handleEnterPip(call, result: result)
        case "exitPip":
            handleExitPip(call, result: result)
        case "setSystemVolume":
            handleSetSystemVolume(call, result: result)
        case "getSystemVolume":
            result(Self.getSystemVolume())
        case "setScreenBrightness":
            handleSetScreenBrightness(call, result: result)
        case "getScreenBrightness":
            result(Double(Self.getScreenBrightness()))
        case "setWakelock":
            handleSetWakelock(call, result: result)
        case "setMediaMetadata":
            handleSetMediaMetadata(call, result: result)
        case "setNotificationEnabled":
            handleSetNotificationEnabled(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // =========================================================================
    // MARK: - Lifecycle
    // =========================================================================

    private func handleCreate(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Arguments required.", details: nil))
            return
        }

        let type = args["type"] as? String ?? "network"
        let videoURL: URL

        switch type {
        case "network":
            guard let urlString = args["url"] as? String, let url = URL(string: urlString) else {
                result(FlutterError(code: "INVALID_SOURCE", message: "Network source requires a valid 'url'.", details: nil))
                return
            }
            videoURL = url
        case "asset":
            guard let assetPath = args["assetPath"] as? String else {
                result(FlutterError(code: "INVALID_SOURCE", message: "Asset source requires 'assetPath'.", details: nil))
                return
            }
            let key = registrar.lookupKey(forAsset: assetPath)
            guard let path = Bundle.main.path(forResource: key, ofType: nil) else {
                result(FlutterError(code: "INVALID_SOURCE", message: "Asset not found: \(assetPath)", details: nil))
                return
            }
            videoURL = URL(fileURLWithPath: path)
        case "file":
            guard let filePath = args["filePath"] as? String else {
                result(FlutterError(code: "INVALID_SOURCE", message: "File source requires 'filePath'.", details: nil))
                return
            }
            videoURL = URL(fileURLWithPath: filePath)
        default:
            result(FlutterError(code: "INVALID_SOURCE", message: "Unknown source type: \(type)", details: nil))
            return
        }

        // Build AVPlayer
        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        player.actionAtItemEnd = .none

        // Video output for texture rendering
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: outputSettings)
        playerItem.add(videoOutput)

        // Create event sink and player instance
        let eventSink = QueuingEventSink()
        let instance = PlayerInstance(
            player: player,
            playerItem: playerItem,
            videoOutput: videoOutput,
            eventSink: eventSink
        )

        // Register as Flutter texture
        let textureId = registrar.textures.register(instance)
        instance.textureId = textureId
        instance.textureRegistry = registrar.textures

        // Event channel
        let eventChannel = FlutterEventChannel(
            name: "\(Self.channelName)/events/\(textureId)",
            binaryMessenger: registrar.messenger
        )
        eventChannel.setStreamHandler(eventSink)
        instance.eventChannel = eventChannel

        // Invisible player layer for PIP support
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        playerLayer.opacity = 0
        if let contentView = registrar.view {
            contentView.layer?.addSublayer(playerLayer)
        }
        instance.playerLayer = playerLayer

        // PIP controller
        if AVPictureInPictureController.isPictureInPictureSupported() {
            let pipController = AVPictureInPictureController(playerLayer: playerLayer)
            pipController?.delegate = instance
            instance.pipController = pipController
        }

        // Set up observers and frame delivery
        instance.setupObservers()
        instance.startDisplayLink()

        players[textureId] = instance
        result(textureId)
    }

    private func handleDispose(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let playerId = playerIdFrom(call, result: result) else { return }
        disposePlayer(playerId)
        result(nil)
    }

    private func disposePlayer(_ playerId: Int64) {
        guard let instance = players.removeValue(forKey: playerId) else { return }
        instance.dispose()
        registrar.textures.unregisterTexture(playerId)
    }

    // =========================================================================
    // MARK: - Playback
    // =========================================================================

    private func handleSeekTo(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let instance = getPlayer(call, result: result) else { return }
        guard let args = call.arguments as? [String: Any],
              let positionMs = (args["position"] as? NSNumber)?.int64Value else {
            result(FlutterError(code: "INVALID_ARGS", message: "position is required.", details: nil))
            return
        }
        let time = CMTime(value: positionMs, timescale: 1000)
        instance.player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            result(nil)
        }
    }

    private func handleSetPlaybackSpeed(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let instance = getPlayer(call, result: result) else { return }
        guard let args = call.arguments as? [String: Any],
              let speed = (args["speed"] as? NSNumber)?.floatValue else {
            result(FlutterError(code: "INVALID_ARGS", message: "speed is required.", details: nil))
            return
        }
        instance.playbackSpeed = speed
        if instance.player.rate != 0 {
            instance.player.rate = speed
        }
        result(nil)
    }

    private func handleSetLooping(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let instance = getPlayer(call, result: result) else { return }
        guard let args = call.arguments as? [String: Any],
              let looping = args["looping"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGS", message: "looping is required.", details: nil))
            return
        }
        instance.isLooping = looping
        result(nil)
    }

    private func handleSetVolume(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let instance = getPlayer(call, result: result) else { return }
        guard let args = call.arguments as? [String: Any],
              let volume = (args["volume"] as? NSNumber)?.floatValue else {
            result(FlutterError(code: "INVALID_ARGS", message: "volume is required.", details: nil))
            return
        }
        instance.player.volume = max(0, min(1, volume))
        result(nil)
    }

    // =========================================================================
    // MARK: - PIP
    // =========================================================================

    private func handleEnterPip(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let instance = getPlayer(call, result: result) else { return }
        guard let pipController = instance.pipController else {
            result(FlutterError(code: "PIP_UNAVAILABLE", message: "PIP is not available.", details: nil))
            return
        }
        pipController.startPictureInPicture()
        result(nil)
    }

    private func handleExitPip(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let instance = getPlayer(call, result: result) else { return }
        instance.pipController?.stopPictureInPicture()
        result(nil)
    }

    // =========================================================================
    // MARK: - System Controls
    // =========================================================================

    private func handleSetSystemVolume(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let volume = (args["volume"] as? NSNumber)?.floatValue else {
            result(FlutterError(code: "INVALID_ARGS", message: "volume is required.", details: nil))
            return
        }
        Self.setSystemVolume(Double(max(0, min(1, volume))))
        result(nil)
    }

    private func handleSetScreenBrightness(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let brightness = (args["brightness"] as? NSNumber)?.floatValue else {
            result(FlutterError(code: "INVALID_ARGS", message: "brightness is required.", details: nil))
            return
        }
        Self.setScreenBrightness(max(0, min(1, brightness)))
        result(nil)
    }

    private func handleSetWakelock(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGS", message: "enabled is required.", details: nil))
            return
        }

        if enabled {
            if wakelockAssertionID == 0 {
                IOPMAssertionCreateWithName(
                    kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                    "av_player video playback" as CFString,
                    &wakelockAssertionID
                )
            }
        } else {
            if wakelockAssertionID != 0 {
                IOPMAssertionRelease(wakelockAssertionID)
                wakelockAssertionID = 0
            }
        }
        result(nil)
    }

    // =========================================================================
    // MARK: - System Volume (CoreAudio)
    // =========================================================================

    private static func getDefaultOutputDevice() -> AudioDeviceID {
        var deviceId = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceId
        )
        return deviceId
    }

    private static func getSystemVolume() -> Double {
        let deviceId = getDefaultOutputDevice()
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)

        // Try main channel (0) first, then left channel (1)
        for element: UInt32 in [0, 1] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            if AudioObjectHasProperty(deviceId, &address) {
                AudioObjectGetPropertyData(deviceId, &address, 0, nil, &size, &volume)
                return Double(volume)
            }
        }
        return 0.0
    }

    private static func setSystemVolume(_ volume: Double) {
        let deviceId = getDefaultOutputDevice()
        var vol = Float32(volume)
        let size = UInt32(MemoryLayout<Float32>.size)

        // Try main channel (0) first, then set both left (1) and right (2)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        if AudioObjectHasProperty(deviceId, &address) {
            AudioObjectSetPropertyData(deviceId, &address, 0, nil, size, &vol)
        } else {
            // Set per-channel
            for element: UInt32 in [1, 2] {
                address.mElement = element
                if AudioObjectHasProperty(deviceId, &address) {
                    AudioObjectSetPropertyData(deviceId, &address, 0, nil, size, &vol)
                }
            }
        }
    }

    // =========================================================================
    // MARK: - Screen Brightness (IOKit)
    // =========================================================================

    private static func getScreenBrightness() -> Float {
        var brightness: Float = 0.5
        var iterator = io_iterator_t()
        let matching = IOServiceMatching("IODisplayConnect")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return brightness
        }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var value: Float = 0
            if IODisplayGetFloatParameter(service, 0, "brightness" as CFString, &value) == KERN_SUCCESS {
                brightness = value
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
        return brightness
    }

    private static func setScreenBrightness(_ brightness: Float) {
        var iterator = io_iterator_t()
        let matching = IOServiceMatching("IODisplayConnect")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return
        }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            IODisplaySetFloatParameter(service, 0, "brightness" as CFString, brightness)
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
    }

    // =========================================================================
    // MARK: - Media Session
    // =========================================================================

    private func handleSetMediaMetadata(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let instance = getPlayer(call, result: result) else { return }
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Arguments required.", details: nil))
            return
        }

        instance.metadataTitle = args["title"] as? String
        instance.metadataArtist = args["artist"] as? String
        instance.metadataAlbum = args["album"] as? String
        let artworkUrl = args["artworkUrl"] as? String

        instance.updateNowPlayingInfo()

        // Load artwork in background if URL changed
        if let urlString = artworkUrl, urlString != instance.artworkUrl {
            instance.artworkUrl = urlString
            if let url = URL(string: urlString) {
                URLSession.shared.dataTask(with: url) { [weak instance] data, _, _ in
                    guard let instance = instance, let data = data, let image = NSImage(data: data) else { return }
                    DispatchQueue.main.async {
                        instance.artworkImage = image
                        instance.updateNowPlayingInfo()
                    }
                }.resume()
            }
        }

        result(nil)
    }

    private func handleSetNotificationEnabled(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let instance = getPlayer(call, result: result) else { return }
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGS", message: "enabled is required.", details: nil))
            return
        }

        instance.notificationEnabled = enabled

        if enabled {
            instance.setupRemoteCommands()
            instance.updateNowPlayingInfo()
        } else {
            instance.tearDownRemoteCommands()
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }

        result(nil)
    }

    // =========================================================================
    // MARK: - Helpers
    // =========================================================================

    private func withPlayer(_ call: FlutterMethodCall, result: @escaping FlutterResult, action: (PlayerInstance) -> Void) {
        guard let instance = getPlayer(call, result: result) else { return }
        action(instance)
        result(nil)
    }

    private func getPlayer(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> PlayerInstance? {
        guard let playerId = playerIdFrom(call, result: result) else { return nil }
        guard let instance = players[playerId] else {
            result(FlutterError(code: "NO_PLAYER", message: "Player \(playerId) not found.", details: nil))
            return nil
        }
        return instance
    }

    private func playerIdFrom(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Int64? {
        guard let args = call.arguments as? [String: Any],
              let playerId = (args["playerId"] as? NSNumber)?.int64Value else {
            result(FlutterError(code: "INVALID_ARGS", message: "playerId is required.", details: nil))
            return nil
        }
        return playerId
    }
}

// =============================================================================
// MARK: - Player Instance
// =============================================================================

private class PlayerInstance: NSObject, FlutterTexture, AVPictureInPictureControllerDelegate {
    let player: AVPlayer
    let playerItem: AVPlayerItem
    let videoOutput: AVPlayerItemVideoOutput
    let eventSink: QueuingEventSink

    var textureId: Int64 = -1
    weak var textureRegistry: FlutterTextureRegistry?
    var eventChannel: FlutterEventChannel?
    var displayLink: CVDisplayLink?
    var playerLayer: AVPlayerLayer?
    var pipController: AVPictureInPictureController?

    var isLooping = false
    var playbackSpeed: Float = 1.0
    var notificationEnabled = false
    var metadataTitle: String?
    var metadataArtist: String?
    var metadataAlbum: String?
    var artworkUrl: String?
    var artworkImage: NSImage?
    private var remoteCommandsRegistered = false
    private var isInitialized = false
    private var isDisposed = false

    private var lastPixelBuffer: CVPixelBuffer?
    private let pixelBufferLock = NSLock()

    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var loadedTimeRangesObservation: NSKeyValueObservation?
    private var timeControlStatusObservation: NSKeyValueObservation?

    init(
        player: AVPlayer,
        playerItem: AVPlayerItem,
        videoOutput: AVPlayerItemVideoOutput,
        eventSink: QueuingEventSink
    ) {
        self.player = player
        self.playerItem = playerItem
        self.videoOutput = videoOutput
        self.eventSink = eventSink
        super.init()
    }

    // MARK: - FlutterTexture

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        pixelBufferLock.lock()
        defer { pixelBufferLock.unlock() }
        guard let buffer = lastPixelBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }

    // MARK: - Display Link (CVDisplayLink)

    func startDisplayLink() {
        guard displayLink == nil else { return }
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let link = displayLink else { return }

        let opaquePtr = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, context) -> CVReturn in
            guard let context = context else { return kCVReturnError }
            let instance = Unmanaged<PlayerInstance>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                instance.displayLinkFired()
            }
            return kCVReturnSuccess
        }, opaquePtr)

        CVDisplayLinkStart(link)
    }

    private func displayLinkFired() {
        guard !isDisposed else { return }
        let outputTime = videoOutput.itemTime(forHostTime: CACurrentMediaTime())
        guard outputTime.isValid, outputTime.isNumeric else { return }

        if videoOutput.hasNewPixelBuffer(forItemTime: outputTime) {
            if let buffer = videoOutput.copyPixelBuffer(
                forItemTime: outputTime,
                itemTimeForDisplay: nil
            ) {
                pixelBufferLock.lock()
                lastPixelBuffer = buffer
                pixelBufferLock.unlock()
                textureRegistry?.textureFrameAvailable(textureId)
            }
        }
    }

    // MARK: - Observers

    func setupObservers() {
        // Player item status (readyToPlay / failed)
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async { self?.handleStatusChange(item.status) }
        }

        // Buffered time ranges
        loadedTimeRangesObservation = playerItem.observe(\.loadedTimeRanges, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async { self?.handleBufferingUpdate(item) }
        }

        // Time control status (playing / paused / waitingToPlay)
        timeControlStatusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async { self?.handleTimeControlStatusChange(player.timeControlStatus) }
        }

        // Periodic position reporting (~5 times/sec)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 200, timescale: 1000),
            queue: .main
        ) { [weak self] time in
            guard let self = self, !self.isDisposed else { return }
            let positionMs = Int64(CMTimeGetSeconds(time) * 1000)
            self.eventSink.success([
                "type": "positionChanged",
                "position": max(0, positionMs),
            ])
        }

        // Playback completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }

    private func handleStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            guard !isInitialized else { return }
            isInitialized = true
            let duration = playerItem.duration
            let durationMs = duration.isIndefinite ? 0 : Int64(CMTimeGetSeconds(duration) * 1000)
            let size = playerItem.presentationSize
            eventSink.success([
                "type": "initialized",
                "duration": max(0, durationMs),
                "width": Double(size.width),
                "height": Double(size.height),
                "textureId": textureId,
            ])
            eventSink.success([
                "type": "playbackStateChanged",
                "state": "ready",
            ])
        case .failed:
            eventSink.success([
                "type": "error",
                "message": playerItem.error?.localizedDescription ?? "Unknown error",
                "code": "PLAYER_ITEM_FAILED",
            ])
        default:
            break
        }
    }

    private func handleBufferingUpdate(_ item: AVPlayerItem) {
        guard let range = item.loadedTimeRanges.first?.timeRangeValue else { return }
        let bufferedMs = Int64(CMTimeGetSeconds(range.start + range.duration) * 1000)
        eventSink.success([
            "type": "bufferingUpdate",
            "buffered": max(0, bufferedMs),
        ])
    }

    private func handleTimeControlStatusChange(_ status: AVPlayer.TimeControlStatus) {
        guard isInitialized else { return }
        let state: String
        switch status {
        case .playing:
            state = "playing"
        case .paused:
            state = "paused"
        case .waitingToPlayAtSpecifiedRate:
            state = "buffering"
        @unknown default:
            state = "idle"
        }
        eventSink.success([
            "type": "playbackStateChanged",
            "state": state,
        ])
        updateNowPlayingInfo()
    }

    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        eventSink.success(["type": "completed"])
        eventSink.success([
            "type": "playbackStateChanged",
            "state": "completed",
        ])

        if isLooping {
            player.seek(to: .zero) { [weak self] _ in
                guard let self = self else { return }
                self.player.play()
                if self.playbackSpeed != 1.0 {
                    self.player.rate = self.playbackSpeed
                }
            }
        }
    }

    // MARK: - AVPictureInPictureControllerDelegate

    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        eventSink.success([
            "type": "pipChanged",
            "isInPipMode": true,
        ])
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        eventSink.success([
            "type": "pipChanged",
            "isInPipMode": false,
        ])
    }

    // MARK: - Media Session

    func updateNowPlayingInfo() {
        guard notificationEnabled else { return }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: metadataTitle ?? "",
            MPMediaItemPropertyArtist: metadataArtist ?? "",
            MPMediaItemPropertyAlbumTitle: metadataAlbum ?? "",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: CMTimeGetSeconds(player.currentTime()),
            MPMediaItemPropertyPlaybackDuration: CMTimeGetSeconds(playerItem.duration.isIndefinite ? .zero : playerItem.duration),
            MPNowPlayingInfoPropertyPlaybackRate: Double(player.rate),
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]

        if let image = artworkImage {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func setupRemoteCommands() {
        guard !remoteCommandsRegistered else { return }
        remoteCommandsRegistered = true

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.player.play()
            if self.playbackSpeed != 1.0 {
                self.player.rate = self.playbackSpeed
            }
            self.eventSink.success([
                "type": "mediaCommand",
                "command": "play",
            ])
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.player.pause()
            self.eventSink.success([
                "type": "mediaCommand",
                "command": "pause",
            ])
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.player.rate > 0 {
                self.player.pause()
                self.eventSink.success([
                    "type": "mediaCommand",
                    "command": "pause",
                ])
            } else {
                self.player.play()
                if self.playbackSpeed != 1.0 {
                    self.player.rate = self.playbackSpeed
                }
                self.eventSink.success([
                    "type": "mediaCommand",
                    "command": "play",
                ])
            }
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.eventSink.success([
                "type": "mediaCommand",
                "command": "next",
            ])
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.eventSink.success([
                "type": "mediaCommand",
                "command": "previous",
            ])
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let time = CMTime(seconds: positionEvent.positionTime, preferredTimescale: 1000)
            self.player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            let positionMs = Int64(positionEvent.positionTime * 1000)
            self.eventSink.success([
                "type": "mediaCommand",
                "command": "seekTo",
                "seekPosition": max(0, positionMs),
            ])
            return .success
        }
    }

    func tearDownRemoteCommands() {
        guard remoteCommandsRegistered else { return }
        remoteCommandsRegistered = false

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
    }

    // MARK: - Cleanup

    func dispose() {
        guard !isDisposed else { return }
        isDisposed = true

        tearDownRemoteCommands()
        if notificationEnabled {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }

        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
        }

        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }

        statusObservation?.invalidate()
        statusObservation = nil
        loadedTimeRangesObservation?.invalidate()
        loadedTimeRangesObservation = nil
        timeControlStatusObservation?.invalidate()
        timeControlStatusObservation = nil

        NotificationCenter.default.removeObserver(self)

        pipController?.delegate = nil
        pipController = nil

        playerLayer?.removeFromSuperlayer()
        playerLayer = nil

        player.pause()
        player.replaceCurrentItem(with: nil)
        playerItem.remove(videoOutput)

        eventChannel?.setStreamHandler(nil)
        eventChannel = nil

        pixelBufferLock.lock()
        lastPixelBuffer = nil
        pixelBufferLock.unlock()
    }

    deinit {
        dispose()
    }
}

// =============================================================================
// MARK: - Queuing Event Sink
// =============================================================================

/// Buffers events until a Dart listener attaches, then flushes them.
private class QueuingEventSink: NSObject, FlutterStreamHandler {
    private var delegate: FlutterEventSink?
    private var queue: [[String: Any]] = []
    private var done = false

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        delegate = events
        for event in queue {
            events(event)
        }
        queue.removeAll()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        delegate = nil
        return nil
    }

    func success(_ event: [String: Any]) {
        if done { return }
        if let sink = delegate {
            sink(event)
        } else {
            queue.append(event)
        }
    }

    func error(code: String, message: String?, details: Any?) {
        if done { return }
        delegate?(FlutterError(code: code, message: message, details: details))
    }

    func endOfStream() {
        done = true
        delegate?(FlutterEndOfEventStream)
    }
}
