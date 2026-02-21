Pod::Spec.new do |s|
  s.name             = 'av_player'
  s.version          = '0.4.0'
  s.summary          = 'macOS implementation of the av_player plugin.'
  s.description      = <<-DESC
  macOS implementation of av_player. Uses AVPlayer for video
  playback, AVPictureInPictureController for PIP, MPNowPlayingInfoCenter
  for media session, and native macOS APIs for system controls.
                       DESC
  s.homepage         = 'https://github.com/FlutterPlaza/av_player'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = { 'FlutterPlaza' => 'contact@flutterplaza.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'av_player/Sources/av_player/**/*.swift'
  s.dependency 'FlutterMacOS'

  s.platform = :osx
  s.osx.deployment_target = '12.0'
  s.swift_version = '5.0'

  s.frameworks = 'AVFoundation', 'AVKit', 'AppKit', 'MediaPlayer', 'CoreAudio', 'IOKit'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
