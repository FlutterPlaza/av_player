import Flutter
import UIKit
import AVFoundation
import AVKit
import MediaPlayer
import VideoToolbox

// =============================================================================
// MARK: - Plugin
// =============================================================================

@objc(AvPlayerPlugin)
public class AvPlayerPlugin: NSObject, FlutterPlugin, AvPlayerHostApi {
    private let registrar: FlutterPluginRegistrar
    private var players: [Int64: PlayerInstance] = [:]

    static let channelName = "com.flutterplaza.av_player_ios"

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = AvPlayerPlugin(registrar: registrar)
        AvPlayerHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    }

    // =========================================================================
    // MARK: - Helpers
    // =========================================================================

    private func getPlayer(_ playerId: Int64) -> Result<PlayerInstance, PigeonError> {
        guard let instance = players[playerId] else {
            return .failure(PigeonError(code: "NO_PLAYER", message: "Player \(playerId) not found.", details: nil))
        }
        return .success(instance)
    }

    private static var keyWindowRootView: UIView? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?
                .rootViewController?.view
        } else {
            return UIApplication.shared.windows
                .first(where: { $0.isKeyWindow })?
                .rootViewController?.view
        }
    }

    // =========================================================================
    // MARK: - AvPlayerHostApi: Lifecycle
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
            guard let path = Bundle.main.path(forResource: key, ofType: nil) else {
                completion(.failure(PigeonError(code: "INVALID_SOURCE", message: "Asset not found: \(assetPath)", details: nil)))
                return
            }
            videoURL = URL(fileURLWithPath: path)
        case .file:
            guard let filePath = source.filePath else {
                completion(.failure(PigeonError(code: "INVALID_SOURCE", message: "File source requires 'filePath'.", details: nil)))
                return
            }
            videoURL = URL(fileURLWithPath: filePath)
        }

        // Configure audio session for video playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal
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
        let textureId = registrar.textures().register(instance)
        instance.textureId = textureId
        instance.textureRegistry = registrar.textures()

        // Event channel
        let eventChannel = FlutterEventChannel(
            name: "\(Self.channelName)/events/\(textureId)",
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(eventSink)
        instance.eventChannel = eventChannel

        // Invisible player layer for PIP support
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        playerLayer.opacity = 0
        if let rootView = Self.keyWindowRootView {
            rootView.layer.addSublayer(playerLayer)
        }
        instance.playerLayer = playerLayer

        // PIP controller
        if AVPictureInPictureController.isPictureInPictureSupported() {
            let pipController = AVPictureInPictureController(playerLayer: playerLayer)
            pipController?.delegate = instance
            if #available(iOS 14.2, *) {
                pipController?.canStartPictureInPictureAutomaticallyFromInline = true
            }
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
        registrar.textures().unregisterTexture(playerId)
    }

    // =========================================================================
    // MARK: - AvPlayerHostApi: Playback
    // =========================================================================

    func play(playerId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        switch getPlayer(playerId) {
        case .success(let instance):
            instance.player.play()
            if instance.playbackSpeed != 1.0 {
                instance.player.rate = instance.playbackSpeed
            }
            completion(.success(()))
        case .failure(let error):
            completion(.failure(error))
        }
    }

    func pause(playerId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        switch getPlayer(playerId) {
        case .success(let instance):
            instance.player.pause()
            completion(.success(()))
        case .failure(let error):
            completion(.failure(error))
        }
    }

    func seekTo(playerId: Int64, positionMs: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        switch getPlayer(playerId) {
        case .success(let instance):
            let time = CMTime(value: positionMs, timescale: 1000)
            instance.player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                completion(.success(()))
            }
        case .failure(let error):
            completion(.failure(error))
        }
    }

    func setPlaybackSpeed(playerId: Int64, speed: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        switch getPlayer(playerId) {
        case .success(let instance):
            instance.playbackSpeed = Float(speed)
            if instance.player.rate != 0 {
                instance.player.rate = Float(speed)
            }
            completion(.success(()))
        case .failure(let error):
            completion(.failure(error))
        }
    }

    func setLooping(playerId: Int64, looping: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        switch getPlayer(playerId) {
        case .success(let instance):
            instance.isLooping = looping
            completion(.success(()))
        case .failure(let error):
            completion(.failure(error))
        }
    }

    func setVolume(playerId: Int64, volume: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        switch getPlayer(playerId) {
        case .success(let instance):
            instance.player.volume = max(0, min(1, Float(volume)))
            completion(.success(()))
        case .failure(let error):
            completion(.failure(error))
        }
    }

    // =========================================================================
    // MARK: - AvPlayerHostApi: PIP
    // =========================================================================

    func isPipAvailable(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(AVPictureInPictureController.isPictureInPictureSupported()))
    }

    func enterPip(request: EnterPipRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        switch getPlayer(request.playerId) {
        case .success(let instance):
            guard let pipController = instance.pipController else {
                completion(.failure(PigeonError(code: "PIP_UNAVAILABLE", message: "PIP is not available.", details: nil)))
                return
            }
            pipController.startPictureInPicture()
            completion(.success(()))
        case .failure(let error):
            completion(.failure(error))
        }
    }

    func exitPip(playerId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        switch getPlayer(playerId) {
        case .success(let instance):
            instance.pipController?.stopPictureInPicture()
            completion(.success(()))
        case .failure(let error):
            completion(.failure(error))
        }
    }

    // =========================================================================
    // MARK: - AvPlayerHostApi: Performance
    // =========================================================================

    func setAbrConfig(request: SetAbrConfigRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        switch getPlayer(request.playerId) {
        case .success(let instance):
            if let maxBitrate = request.config.maxBitrateBps {
                instance.playerItem.preferredPeakBitRate = Double(maxBitrate)
            }
            if let maxWidth = request.config.preferredMaxWidth,
               let maxHeight = request.config.preferredMaxHeight {
                if #available(iOS 11.0, *) {
                    instance.playerItem.preferredMaximumResolution = CGSize(
                        width: CGFloat(maxWidth), height: CGFloat(maxHeight))
                }
            }
            completion(.success(()))
        case .failure(let error):
            completion(.failure(error))
        }
    }

    func getDecoderInfo(playerId: Int64, completion: @escaping (Result<DecoderInfoMessage, Error>) -> Void) {
        var hwH264 = false
        var hwHEVC = false
        if #available(iOS 11.0, *) {
            hwH264 = VTIsHardwareDecodeSupported(kCMVideoCodecType_H264)
            hwHEVC = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)
        }
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

    // =========================================================================
    // MARK: - AvPlayerHostApi: System Controls
    // =========================================================================

    func setSystemVolume(volume: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.failure(PigeonError(
            code: "UNSUPPORTED",
            message: "iOS does not support programmatic system volume changes.",
            details: nil
        )))
    }

    func getSystemVolume(completion: @escaping (Result<Double, Error>) -> Void) {
        completion(.success(Double(AVAudioSession.sharedInstance().outputVolume)))
    }

    func setScreenBrightness(brightness: Double, completion: @escaping (Result<Void, Error>) -> Void) {
        UIScreen.main.brightness = CGFloat(max(0, min(1, brightness)))
        completion(.success(()))
    }

    func getScreenBrightness(completion: @escaping (Result<Double, Error>) -> Void) {
        completion(.success(Double(UIScreen.main.brightness)))
    }

    func setWakelock(enabled: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        UIApplication.shared.isIdleTimerDisabled = enabled
        completion(.success(()))
    }

    // =========================================================================
    // MARK: - AvPlayerHostApi: Media Session
    // =========================================================================

    func setMediaMetadata(request: MediaMetadataRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        switch getPlayer(request.playerId) {
        case .success(let instance):
            instance.metadataTitle = request.metadata.title
            instance.metadataArtist = request.metadata.artist
            instance.metadataAlbum = request.metadata.album
            let artworkUrl = request.metadata.artworkUrl

            instance.updateNowPlayingInfo()

            // Load artwork in background if URL changed
            if let urlString = artworkUrl, urlString != instance.artworkUrl {
                instance.artworkUrl = urlString
                if let url = URL(string: urlString) {
                    URLSession.shared.dataTask(with: url) { [weak instance] data, _, _ in
                        guard let instance = instance, let data = data, let image = UIImage(data: data) else { return }
                        DispatchQueue.main.async {
                            instance.artworkImage = image
                            instance.updateNowPlayingInfo()
                        }
                    }.resume()
                }
            }

            completion(.success(()))
        case .failure(let error):
            completion(.failure(error))
        }
    }

    func setNotificationEnabled(playerId: Int64, enabled: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        switch getPlayer(playerId) {
        case .success(let instance):
            instance.notificationEnabled = enabled

            if enabled {
                instance.setupRemoteCommands()
                instance.updateNowPlayingInfo()
            } else {
                instance.tearDownRemoteCommands()
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            }

            completion(.success(()))
        case .failure(let error):
            completion(.failure(error))
        }
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
    var displayLink: CADisplayLink?
    var playerLayer: AVPlayerLayer?
    var pipController: AVPictureInPictureController?

    var isLooping = false
    var playbackSpeed: Float = 1.0
    var notificationEnabled = false
    var metadataTitle: String?
    var metadataArtist: String?
    var metadataAlbum: String?
    var artworkUrl: String?
    var artworkImage: UIImage?
    private var remoteCommandsRegistered = false
    private var isInitialized = false
    private var isDisposed = false
    private var memoryWarningObserver: NSObjectProtocol?
    private var accessLogObserver: NSObjectProtocol?

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

    // MARK: - Display Link

    func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func displayLinkFired(_ link: CADisplayLink) {
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

        // Memory pressure
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.eventSink.success([
                "type": "memoryPressure",
                "level": "critical",
            ])
        }

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

        displayLink?.invalidate()
        displayLink = nil

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

        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
            memoryWarningObserver = nil
        }
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
