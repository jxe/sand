# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/ios'
require 'rubygems'
require 'bundler'
require 'bubble-wrap'
require 'nitron'
require 'motion-cocoapods'

Bundler.require

Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'Sand'
  app.identifier = 'org.nxhx.sand'
  app.version = '1.0.0'
  app.frameworks += ['EventKit', 'EventKitUI', 'AddressBook', 'AddressBookUI', 'QuartzCore']
  app.icons = ['dune.png']
  app.files += Dir.glob("./src/*.rb")
  app.build_dir = '/tmp/build-sands/'
  app.interface_orientations = [:portrait]
  app.sdk_version = "7.0"
  app.deployment_target = "7.0"
  app.device_family = [:iphone]
  # app.codesign_certificate = 'iPhone Distribution: Joseph Edelman (B7P78ULCXS)'
  # app.provisioning_profile = "/Users/joe/Library/MobileDevice/Provisioning Profiles/18AE990C-F028-4725-891B-9A4CD179291F.mobileprovision"

  app.pods do
    pod 'RESideMenu' #, '~> 2.0.2'
  end

  app.release do
    app.seed_id = 'B7P78ULCXS'
  end

  app.development do
    # This entitlement is required during development but must not be used for release.
    # app.entitlements['get-task-allow'] = false
  end
end
