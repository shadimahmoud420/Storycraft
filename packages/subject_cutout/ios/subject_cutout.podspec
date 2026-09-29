Pod::Spec.new do |s|
  s.name             = 'subject_cutout'
  s.version          = '1.0.0'
  s.summary          = 'On-device background removal with Apple Vision.'
  s.homepage         = 'https://example.com'
  s.license          = { :type => 'MIT' }
  s.author           = { 'StoryCraft' => 'dev@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.frameworks       = 'Vision', 'CoreImage'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
