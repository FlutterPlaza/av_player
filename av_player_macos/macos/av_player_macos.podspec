Pod::Spec.new do |s|
  s.name             = 'av_player_macos'
  s.version          = '0.2.0-beta.1'
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
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx
  s.osx.deployment_target = '12.0'
  s.swift_version = '5.0'

  s.frameworks = 'AVFoundation', 'AVKit', 'AppKit', 'MediaPlayer', 'CoreAudio', 'IOKit'
end
