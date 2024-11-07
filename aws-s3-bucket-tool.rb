#!/usr/bin/env ruby

require_relative "ui-helper"
require_relative "s3-helper"
require 'aws-sdk-s3'
require 'curses'

PAGE_SIZE = 20 # Number of items per page

def main(s3)
  Curses.init_screen
  Curses.curs_set(0)
  Curses.noecho
  begin
    window = Curses.stdscr
    window.clear
    ui = UiHelper.new(window, PAGE_SIZE)
    browser = S3Helper.new(s3, ui, PAGE_SIZE)

    # Initial loop to select a bucket
    bucket = ARGV[0] || browser.select_bucket

    # Proceed to navigate within the valid bucket
    loop do
      result = browser.navigate_bucket(bucket)
      break unless result == :restart # Restart bucket selection if :restart is returned
      bucket = select_bucket(s3, ui, browser) # Select a new bucket if user chooses to restart
    end

  rescue Aws::Sigv4::Errors::MissingCredentialsError
    ui.display_info("AWS credentials not found. Please configure your AWS credentials. (Check your current config.)")
  rescue Aws::Errors::ServiceError => e
    ui.display_info("An error occurred with AWS: #{e.message} | (Check your spelling and your current config.)")
  ensure
    Curses.close_screen
  end
end

s3 = Aws::S3::Client.new
main(s3)
