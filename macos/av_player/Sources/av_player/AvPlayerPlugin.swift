import FlutterMacOS
import Foundation
import AVFoundation
import AVKit
import MediaPlayer
import CoreAudio
import IOKit
import IOKit.pwr_mgt
import VideoToolbox

// =============================================================================
// MARK: - Plugin
// =============================================================================

@objc(AvPlayerPlugin)
public class AvPlayerPlugin: NSObject, FlutterPlugin, AvPlayerHostApi {
    private let registrar: FlutterPluginRegistrar
    private var players: [Int64: PlayerInstance] = [:]
    private var wakelockAssertionID: IOPMAssertionID = 0
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    static let channelName = "com.flutterplaza.av_player_macos"

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = AvPlayerPlugin(registrar: registrar)
        AvPlayerHostApiSetup.setUp(binaryMessenger: registrar.messenger, api: instance)
        instance.setupMemoryPressureMonitoring()
    }

    // =========================================================================
    // MARK: - AvPlayerHostApi — Lifecycle
    // =========================================================================

    func create(source: VideoSourceMessage, completion: @escaping (Result<Int64, Error>) -> Void) {
        let videoURL: URL

        switch source.type {
        case .network:
            guard let urlString = source.url, let url = URL(string: urlString) else {
                completion(.failure(PigeonError(code: "INVALID_SOURCE", message: "Network source requires a valid 'url'.", details: nil)))
                return
            }
            videoURL = url
        case .asset:
            guard let assetPath = source.assetPath else {
                completion(.failure(PigeonError(code: "INVALID_SOURCE", message: "Asset source requires 'assetPath'.", details: nil)))
                return
            }
            let key = registrar.lookupKey(forAsset: assetPath)
            // On macOS, lookupKey returns a path relative to the main bundle
            // root (e.g. "Contents/Frameworks/App.framework/Resources/flutter_assets/…").
            // Bundle.path(forResource:) cannot resolve this, so we construct
            // the full path directly.
            let fullPath = "\(Bundle.main.bundlePath)/\(key)"
            guard FileManager.default.fileExists(atPath: fullPath) else {
                completion(.failure(PigeonError(code: "INVALID_SOURCE", message: "Asset not found: \(assetPath)", details: nil)))
                return
            }
            videoURL = URL(fileURLWithPath: fullPath)
        case .file:
            guard let filePath = source.filePath else {
                completion(.failure(PigeonError(code: "INVALID_SOURCE", message: "File source requires 'filePath'.", details: nil)))
                return
            }
            videoURL = URL(fileURLWithPath: filePath)
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
        completion(.success(textureId))
    }

    func dispose(playerId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        disposePlayer(playerId)
        completion(.success(()))
    }

    private func disposePlayer(_ playerId: Int64) {
        guard let instance = players.removeValue(forKey: playerId) else { return }
        instance.dispose()
        registrar.textures.unregisterTexture(playerId)
    }

    // =========================================================================
    // MARK: - AvPlayerHostApi — Playback
    // =========================================================================

    func play(playerId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let instance = players[playerId] else {
            completion(.failure(PigeonError(code: "NO_PLAYER", message: "Player \(playerId) not found.", details: nil)))
            return
        }
        instance.player.play()
        if instance.playbackSpeed != 1.0 {
            instance.player.rate = instance.playbackSpeed
        }
        completion(.success(()))
    }

    func pause(playerId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let instance = players[playerId] else {
            completion(.failure(PigeonError(code: "NO_PLAYER", message: "Player \(playerId) not found.", details: nil)))
            return
        }
        instance.player.pause()
        completion(.success(()))
    }

    func seekTo(playerId: Int64, positionMs: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let instance = players[playerId] else {
            completion(.failure(PigeonError(code: "NO_PLAYER", message: "Player \(playerId) not found.", details: nil)))
            return
        }
        let time = CMTime(value: positionMs, timescale: 1000)
        instance.player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            completion(.success(()))
        }
    }

    func setPlaybackSpeed(playerId: Int64, speed: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let instance = players[playerId] else {
            completion(.failure(PigeonError(code: "NO_PLAYER", message: "Player \(playerId) not found.", details: nil)))
            return
        }
        instance.playbackSpeed = Float(speed)
        if instance.player.rate != 0 {
            instance.player.rate = Float(speed)
        }
        completion(.success(()))
    }

    func setLooping(playerId: Int64, looping: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let instance = players[playerId] else {
            completion(.failure(PigeonError(code: "NO_PLAYER", message: "Player \(playerId) not found.", details: nil)))
            return
        }
        instance.isLooping = looping
        completion(.success(()))
    }

    func setVolume(playerId: Int64, volume: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let instance = players[playerId] else {
            completion(.failure(PigeonError(code: "NO_PLAYER", message: "Player \(playerId) not found.", details: nil)))
            return
        }
        instance.player.volume = Float(max(0, min(1, volume)))
        completion(.success(()))
    }

    // =========================================================================
    // MARK: - AvPlayerHostApi — PIP
    // =========================================================================

    func isPipAvailable(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(AVPictureInPictureController.isPictureInPictureSupported()))
    }

    func enterPip(request: EnterPipRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let instance = players[request.playerId] else {
            completion(.failure(PigeonError(code: "NO_PLAYER", message: "Player \(request.playerId) not found.", details: nil)))
            return
        }
        guard let pipController = instance.pipController else {
            completion(.failure(PigeonError(code: "PIP_UNAVAILABLE", message: "PIP is not available.", details: nil)))
            return
        }
        pipController.startPictureInPicture()
        completion(.success(()))
    }

    func exitPip(playerId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let instance = players[playerId] else {
            completion(.failure(PigeonError(code: "NO_PLAYER", message: "Player \(playerId) not found.", details: nil)))
            return
        }
        instance.pipController?.stopPictureInPicture()
        completion(.success(()))
    }

    // =========================================================================
    // MARK: - AvPlayerHostApi — Subtitles
    // =========================================================================

    func getSubtitleTracks(playerId: Int64, completion: @escaping (Result<[SubtitleTrackMessage], Error>) -> Void) {
        guard let instance = players[playerId] else {
            completion(.failure(PigeonError(code: "NO_PLAYER", message: "Player \(playerId) not found.", details: nil)))
            return
        }
        var tracks: [SubtitleTrackMessage] = []
        if let group = instance.playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            for (index, option) in group.options.enumerated() {
                let label = option.displayName
                let language = option.locale?.languageCode
                tracks.append(SubtitleTrackMessage(
                    id: "embedded_\(index)",
                    label: label,
                    language: language
                ))
            }
        }
        completion(.success(tracks))
    }

    func selectSubtitleTrack(request: SelectSubtitleTrackRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let instance = players[request.playerId] else {
            completion(.failure(PigeonError(code: "NO_PLAYER", message: "Player \(request.playerId) not found.", details: nil)))
            return
        }

        guard let group = instance.playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            completion(.success(()))
            return
        }

        if let trackId = request.trackId,
           trackId.hasPrefix("embedded_"),
           let indexStr = trackId.split(separator: "_").last,
           let index = Int(indexStr),
           index < group.options.count {
            instance.playerItem.select(group.options[index], in: group)
        } else {
            instance.playerItem.select(nil, in: group)
        }
        completion(.success(()))
    }

    // =========================================================================
    // MARK: - AvPlayerHostApi — Performance
    // =========================================================================

    func setAbrConfig(request: SetAbrConfigRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let instance = players[request.playerId] else {
            completion(.failure(PigeonError(code: "NO_PLAYER", message: "Player \(request.playerId) not found.", details: nil)))
            return
        }
        if let maxBitrate = request.config.maxBitrateBps {
            instance.playerItem.preferredPeakBitRate = Double(maxBitrate)
        }
        if let maxWidth = request.config.preferredMaxWidth,
           let maxHeight = request.config.preferredMaxHeight {
            instance.playerItem.preferredMaximumResolution = CGSize(
                width: CGFloat(maxWidth), height: CGFloat(maxHeight))
        }
        completion(.success(()))
    }

    func getDecoderInfo(playerId: Int64, completion: @escaping (Result<DecoderInfoMessage, Error>) -> Void) {
        let hwH264 = VTIsHardwareDecodeSupported(kCMVideoCodecType_H264)
        let hwHEVC = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)
        let isHW = hwH264 || hwHEVC
        var codecName: String? = nil
        if hwHEVC { codecName = "HEVC" }
        else if hwH264 { codecName = "H.264" }
        completion(.success(DecoderInfoMessage(
            isHardwareAccelerated: isHW,
            decoderName: isHW ? "VideoToolbox" : nil,
            codec: codecName
        )))
    }

    private func setupMemoryPressureMonitoring() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let event = source.data
            let level: String
            if event.contains(.critical) {
                level = "critical"
            } else {
                level = "warning"
            }
            for instance in self.players.values {
                instance.eventSink.success([
                    "type": "memoryPressure",
                    "level": level,
                ])
            }
        }
        source.resume()
        memoryPressureSource = source
    }

    // =========================================================================
    // MARK: - AvPlayerHostApi — System Controls
    // =========================================================================

    func setSystemVolume(volume: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        Self.setSystemVolume(max(0, min(1, volume)))
        completion(.success(()))
    }

    func getSystemVolume(completion: @escaping (Result<Double, Error>) -> Void) {
        completion(.success(Self.getSystemVolume()))
    }

    func setScreenBrightness(brightness: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        Self.setScreenBrightness(Float(max(0, min(1, brightness))))
        completion(.success(()))
    }

    func getScreenBrightness(completion: @escaping (Result<Double, Error>) -> Void) {
        completion(.success(Double(Self.getScreenBrightness())))
    }

    func setWakelock(enabled: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
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
        completion(.success(()))
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
    // MARK: - AvPlayerHostApi — Media Session
    // =========================================================================

    func setMediaMetadata(request: MediaMetadataRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let instance = players[request.playerId] else {
            completion(.failure(PigeonError(code: "NO_PLAYER", message: "Player \(request.playerId) not found.", details: nil)))
            return
        }

        let metadata = request.metadata
        instance.metadataTitle = metadata.title
        instance.metadataArtist = metadata.artist
        instance.metadataAlbum = metadata.album
        let artworkUrl = metadata.artworkUrl

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

        completion(.success(()))
    }

    func setNotificationEnabled(playerId: Int64, enabled: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let instance = players[playerId] else {
            completion(.failure(PigeonError(code: "NO_PLAYER", message: "Player \(playerId) not found.", details: nil)))
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

        completion(.success(()))
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
    private var accessLogObserver: NSObjectProtocol?

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

        // ABR info from access log
        accessLogObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewAccessLogEntry,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self = self,
                  let event = self.playerItem.accessLog()?.events.last else { return }
            let bitrate = Int64(event.indicatedBitrate)
            if bitrate > 0 {
                self.eventSink.success([
                    "type": "abrInfo",
                    "currentBitrateBps": bitrate,
                    "availableBitrateBps": [bitrate],
                ])
            }
        }
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
        if let observer = accessLogObserver {
            NotificationCenter.default.removeObserver(observer)
            accessLogObserver = nil
        }

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
