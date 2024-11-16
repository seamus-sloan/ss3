#!/usr/bin/env ruby
require 'bundler/setup'

# Determine the base directory of the script
base_dir = File.expand_path('..', __FILE__)

# Attempt to load class files from the same directory
begin
  require_relative 's3-navigator'
  require_relative 'ui-navigator'
rescue LoadError
  # If not found, attempt to load from the 'lib' directory (e.g., when installed via Homebrew)
  $LOAD_PATH.unshift(File.join(base_dir, 'lib'))
  require 's3-navigator'
  require 'ui-navigator'
end

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
