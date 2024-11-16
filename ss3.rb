#!/usr/bin/env ruby
require 'bundler/setup'

# When installed with homebrew, the helper files are installed
# in lib/ which requires the below line in order to function.
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 's3-navigator'
require 'ui-navigator'

# Replace the above with the below lines for local development.
# require_relative 's3-navigator'
# require_relative 'ui-navigator'

if ARGV.any? { |arg| ["--help", "-h"].include?(arg) }
  ui_navigator = UINavigator.new(nil)
  ui_navigator.help
end


begin
  s3_navigator = S3Navigator.new(ARGV[0])
  ui_navigator = UINavigator.new(s3_navigator)
  ui_navigator.start
rescue Interrupt
  puts "\nExiting..."
  exit 0
end
