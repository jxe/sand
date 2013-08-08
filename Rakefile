# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project/template/ios'
require 'rubygems'
require 'bundler'
require 'bubble-wrap'
require 'nitron'
Bundler.require

Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'Sands'
  app.identifier = 'org.nxhx.Sands'
  app.version = '1.0.0'
  app.frameworks += ['EventKit', 'EventKitUI', 'AddressBook', 'AddressBookUI', 'QuartzCore']
  app.icons = ['hourglass.png']
  app.files += Dir.glob("./src/*.rb")
  app.build_dir = '/tmp/build-sands/'
  # app.pods do
  #   pod 'FlatUIKit'
  # end
end
