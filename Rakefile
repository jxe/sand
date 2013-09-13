# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
%w{ motion/project/template/ios rubygems bundler bubble-wrap nitron motion-cocoapods }.each{ |x| require x }
Bundler.require
Motion::Project::App.setup do |app|


  app.name = 'Sand'
  app.seed_id = 'B7P78ULCXS'
  app.identifier = 'org.nxhx.sand'
  app.icons = ['cloudy-dune-57.png', 'cloudy-dune-114.png', 'cloudy-dune-120.png']
  app.version = '1.0.0'

  # app.sdk_version = "7.0"
  # app.deployment_target = "7.0"

  app.sdk_version = "7.0"
  app.deployment_target = "6.1"

  app.interface_orientations = [:portrait]
  app.device_family = [:iphone]

  # app.entitlements['get-task-allow'] = false
  # app.entitlements['get-task-allow'] = true

  app.frameworks += ['EventKit', 'EventKitUI', 'AddressBook', 'AddressBookUI', 'QuartzCore']
  app.pods{ pod 'RESideMenu' }

  app.entitlements['application-identifier'] = "#{app.seed_id}.#{app.identifier}"
  app.release do
    app.codesign_certificate = 'iPhone Distribution: Joseph Edelman' #  (B7P78ULCXS)
    app.provisioning_profile = "/Users/joe/Library/MobileDevice/Provisioning Profiles/7A8826C3-DE6C-4B57-84AA-3B91B1CD456B.mobileprovision"
  end

  app.development do
    app.codesign_certificate = 'iPhone Developer: Joe Edelman' #  (B7P78ULCXS)
    app.provisioning_profile = "/Users/joe/Library/MobileDevice/Provisioning Profiles/7D1BDC63-D277-445D-A677-E877285CE20D.mobileprovision"
  end

  app.files += Dir.glob("./src/*.rb")
  app.build_dir = '/tmp/build-sand/'

end
