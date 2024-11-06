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
    ui = UI.new(window, PAGE_SIZE)
    browser = S3Browser.new(s3, ui, PAGE_SIZE)

    # Prompt for a valid bucket name until one is provided
    loop do
      ui.clear_error_message
      bucket = ui.prompt_user("Enter the S3 bucket name: ").strip
      next if bucket.empty? # Retry if input is blank

      # Check if the bucket is valid by attempting to list objects
      items = browser.list_objects(bucket)

      # If there are items in the bucket, continue into normal navigation.
      if items
        result = browser.navigate_bucket(bucket)

        # When trying to use a new bucket from navigate_bucket, restart
        # the process to break out of both loops & reenter the bucket name.
        break unless result == :restart
      end
    end

  rescue Aws::Sigv4::Errors::MissingCredentialsError
    ui.display_error("AWS credentials not found. Please configure your AWS credentials.")
  rescue Aws::Errors::ServiceError => e
    ui.display_error("An error occurred with AWS: #{e.message}")
  ensure
    Curses.close_screen
  end
end

s3 = Aws::S3::Client.new
main(s3)
