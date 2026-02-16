#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'av_player'
  s.version          = '0.3.0'
  s.summary          = 'iOS implementation of the av_player plugin.'
  s.description      = <<-DESC
  iOS implementation of the av_player plugin, providing native
  video playback with AVPlayer, Picture-in-Picture, and system controls.
                       DESC
  s.homepage         = 'https://github.com/FlutterPlaza/av_player'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = { 'FlutterPlaza' => 'dev@flutterplaza.com' }
  s.source           = { :path => '.' }
  s.source_files = 'av_player/Sources/av_player/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.frameworks = 'AVFoundation', 'AVKit', 'UIKit', 'MediaPlayer'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
