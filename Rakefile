# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
%w{ motion/project/template/ios rubygems bundler bubble-wrap motion-cocoapods }.each{ |x| require x }
Bundler.require
Motion::Project::App.setup do |app|

  app.name = 'Sand'
  app.version = '1.0.5'

  app.sdk_version = "7.0"
  # app.deployment_target = "6.1"
  app.deployment_target = "7.0"
  app.device_family = [:iphone]

  app.identifier = 'org.nxhx.sand'
  app.info_plist['FacebookAppID'] = '544764115578692'
  app.info_plist['CFBundleURLTypes'] = [
    { 'CFBundleURLName' => 'org.nxhx.sand',
      'CFBundleURLSchemes' => ['sandapp', 'fb544764115578692'] }
  ]
  app.seed_id = 'B7P78ULCXS'
  app.icons = ['cloudy-dune-57.png', 'cloudy-dune-114.png', 'cloudy-dune-120.png']

  app.info_plist['UILaunchImages'] = [
   {
     'UILaunchImageName' => 'blurry-sand',
     'UILaunchImageMinimumOSVersion' => '7.0',
     'UILaunchImageSize' => '{320, 480}'
   },
   {
     'UILaunchImageName' => 'blurry-sand',
     'UILaunchImageMinimumOSVersion' => '7.0',
     'UILaunchImageSize' => '{320, 568}'
   }
 ]

  app.interface_orientations = [:portrait]

  app.frameworks += %w{ AdSupport Accounts Social EventKit EventKitUI AddressBook AddressBookUI QuartzCore IOKit }
  app.weak_frameworks += %w{ AdSupport Accounts Social }
  app.pods{
    pod 'RequestUtils'
    pod 'Facebook-iOS-SDK', '~> 3.7'
    pod 'SVProgressHUD',  :git => 'https://github.com/samvermette/SVProgressHUD.git', :commit => '1.0'
    pod 'HockeySDK'
  }

  app.entitlements['application-identifier'] = "#{app.seed_id}.#{app.identifier}"
  app.release do
    app.codesign_certificate = 'iPhone Distribution: Joseph Edelman' #  (B7P78ULCXS)
    app.provisioning_profile = "/Users/joe/Library/MobileDevice/Provisioning Profiles/7A8826C3-DE6C-4B57-84AA-3B91B1CD456B.mobileprovision"
  end

  app.development do
    app.codesign_certificate = 'iPhone Developer: Joe Edelman' #  (B7P78ULCXS)
    app.provisioning_profile = "/Users/joe/Library/MobileDevice/Provisioning Profiles/C5317494-CC09-4AC6-A00F-079F29EF4747.mobileprovision"
  end

  app.files += Dir.glob("./src/**/*.rb")
  app.files_dependencies \
    'src/drag/cal_drag_manager.rb' => 'src/drag/drag_manager.rb',
    'src/cal_view_controller.rb' => [
      'src/patch/collection_view_controller_improvements.rb',
      'src/patch/view_controller_improvements.rb'
    ]
  app.build_dir = '/tmp/build-sand/'

end

desc "Generate App Store Build"
task :appstore => [
  :check_versions,
  :clean,
  'pod:install',
  "archive:distribution",
  :send_to_crittercism
]

task :check_versions do
  gitv = `git describe --dirty`.strip
  raise "git wrong version #{gitv}; #{ENV['tag']};" unless gitv == ENV['tag']
  raise "app wrong version" unless Motion::Project::App.config.version == ENV['tag'].sub(/^v/, '1.')
  # should ensure that the checkout is of a clean tag that's been pushed
  # and that the app.version is set right
end

def build_path
  "/tmp/build-sand/iPhoneOS-7.0-Release/"
end

task :send_to_crittercism do
  cmd = <<-CMD
    cd #{build_path} &&
    zip -r Sand.dSYM.zip Sand.dSYM &&
    curl "https://api.crittercism.com/api_beta/dsym/527bdb3dd0d8f74cd4000003"
      -F dsym=@"Sand.dSYM.zip"
      -F key="mkt70lo9yrfnyxbjfq6ousjcpdxazidi"
  CMD
  puts cmd
  sh cmd.gsub("\n", "\\\n")
end
