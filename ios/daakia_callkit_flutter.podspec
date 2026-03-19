Pod::Spec.new do |s|
  s.name             = 'daakia_callkit_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Daakia CallKit Flutter plugin'
  s.description      = <<-DESC
Daakia CallKit Flutter plugin for VoIP token registration and CallKit events.
                       DESC
  s.homepage         = 'https://daakia.co.in'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Daakia' => 'support@daakia.co.in' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency       'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
end
