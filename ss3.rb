#!/usr/bin/env ruby

require_relative 'bundle/bundler/setup'
require_relative 's3-navigator'
require_relative 'ui-navigator'


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
