require "json"
json = File.read(File.join(__dir__, "package.json"))
package = JSON.parse(json).deep_symbolize_keys

Pod::Spec.new do |s|
  s.name         = package[:name]
  s.version      = package[:version]
  s.summary      = package[:description]

  s.homepage     = "https://github.com/spotify/react-native-lookback"
  
  s.license      = { :type => "APACHE", :file => "LICENSE" }
  s.authors = package[:author]
  
  s.platform     = :ios, "10.0"
  s.source       = { :git => "https://github.com/spotify/react-native-lookback", :tag => package[:version] }
  s.source_files  = "ios/*.{h,m}"
  s.requires_arc = true

  s.dependency 'React'
  s.dependency 'Lookback', '~> 3.0'

end

  
