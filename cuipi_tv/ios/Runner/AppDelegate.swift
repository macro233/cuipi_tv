import Flutter
import UIKit
import AVKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, AVPictureInPictureControllerDelegate {
  private var pipController: AVPictureInPictureController?
  private var pipPlayerLayer: AVPlayerLayer?
  private var pipPlayer: AVPlayer?
  private var pipContainerView: UIView?
  private var pipChannel: FlutterMethodChannel?
  private var currentVideoUrl: String?
  private var isPipActive = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1. 配置后台音视频与系统级画中画音频会话
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .moviePlayback, options: [])
      try session.setActive(true)
    } catch {
      print("Cuipi TV: Failed to set AVAudioSession: \(error)")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupPipChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }

  private func setupPipChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "cuipi_tv/pip", binaryMessenger: messenger)
    self.pipChannel = channel

    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      let args = call.arguments as? [String: Any]

      switch call.method {
      case "isPipSupported":
        result(AVPictureInPictureController.isPictureInPictureSupported())

      case "preparePip":
        // 预装载画中画：在播放启动时调用，使得向上滑回桌面时系统可自动弹起画中画 (iOS 14.2+)
        if let urlStr = args?["url"] as? String {
          let posMs = (args?["positionMs"] as? Int) ?? 0
          let isPlaying = (args?["isPlaying"] as? Bool) ?? true
          self.prepareNativePip(urlStr: urlStr, positionMs: posMs, isPlaying: isPlaying)
          result(true)
        } else {
          result(false)
        }

      case "startPip":
        if let urlStr = args?["url"] as? String {
          let posMs = (args?["positionMs"] as? Int) ?? 0
          let isPlaying = (args?["isPlaying"] as? Bool) ?? true
          self.prepareNativePip(urlStr: urlStr, positionMs: posMs, isPlaying: isPlaying)
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.startPipInternal()
          }
          result(true)
        } else if self.pipController != nil {
          self.startPipInternal()
          result(true)
        } else {
          result(false)
        }

      case "stopPip":
        self.stopPipInternal()
        result(true)

      case "syncState":
        if let posMs = args?["positionMs"] as? Int {
          let targetTime = CMTime(value: CMTimeValue(posMs), timescale: 1000)
          self.pipPlayer?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        if let isPlaying = args?["isPlaying"] as? Bool {
          if isPlaying && self.isPipActive {
            self.pipPlayer?.play()
          } else if !isPlaying {
            self.pipPlayer?.pause()
          }
        }
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func prepareNativePip(urlStr: String, positionMs: Int, isPlaying: Bool) {
    guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
    guard let url = URL(string: urlStr) else { return }

    if currentVideoUrl == urlStr, let player = pipPlayer {
      let targetTime = CMTime(value: CMTimeValue(positionMs), timescale: 1000)
      player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
      return
    }

    currentVideoUrl = urlStr
    let playerItem = AVPlayerItem(url: url)
    let player = AVPlayer(playerItem: playerItem)
    self.pipPlayer = player

    if positionMs > 0 {
      let targetTime = CMTime(value: CMTimeValue(positionMs), timescale: 1000)
      player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      guard let rootVC = self.window?.rootViewController else { return }

      if self.pipContainerView == nil {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 160, height: 90))
        container.backgroundColor = .black
        container.isUserInteractionEnabled = false
        container.alpha = 0.01 // 极低透明度但在图层树中保持活跃
        rootVC.view.addSubview(container)
        rootVC.view.sendSubviewToBack(container)
        self.pipContainerView = container
      }

      self.pipPlayerLayer?.removeFromSuperlayer()
      let layer = AVPlayerLayer(player: player)
      layer.frame = self.pipContainerView?.bounds ?? CGRect(x: 0, y: 0, width: 160, height: 90)
      layer.videoGravity = .resizeAspect
      self.pipContainerView?.layer.addSublayer(layer)
      self.pipPlayerLayer = layer

      let pip = AVPictureInPictureController(playerLayer: layer)
      pip?.delegate = self
      if #available(iOS 14.2, *) {
        pip?.canStartPictureInPictureAutomaticallyFromInline = true
      }
      self.pipController = pip
    }
  }

  private func startPipInternal() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, let pip = self.pipController else { return }
      if pip.isPictureInPicturePossible {
        pip.startPictureInPicture()
      } else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
          self.pipController?.startPictureInPicture()
        }
      }
    }
  }

  private func stopPipInternal() {
    DispatchQueue.main.async { [weak self] in
      self?.pipController?.stopPictureInPicture()
      self?.pipPlayer?.pause()
      self?.isPipActive = false
    }
  }

  // MARK: - AVPictureInPictureControllerDelegate
  public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
    isPipActive = true
    pipPlayer?.play()
    pipChannel?.invokeMethod("onPipStarted", arguments: nil)
  }

  public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
    isPipActive = true
  }

  public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
    isPipActive = false
    pipChannel?.invokeMethod("onPipError", arguments: ["error": error.localizedDescription])
  }

  public func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
    if let player = pipPlayer {
      let currentSec = CMTimeGetSeconds(player.currentTime())
      let currentMs = Int(currentSec * 1000)
      let isPlaying = player.rate > 0
      pipChannel?.invokeMethod("onPipWillStop", arguments: ["positionMs": currentMs, "isPlaying": isPlaying])
    }
  }

  public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
    isPipActive = false
    pipPlayer?.pause()
    pipChannel?.invokeMethod("onPipStopped", arguments: nil)
  }

  public func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    if let player = pipPlayer {
      let currentSec = CMTimeGetSeconds(player.currentTime())
      let currentMs = Int(currentSec * 1000)
      let isPlaying = player.rate > 0
      pipChannel?.invokeMethod("onPipRestore", arguments: ["positionMs": currentMs, "isPlaying": isPlaying])
    }
    completionHandler(true)
  }
}
