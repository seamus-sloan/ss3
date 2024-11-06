#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'curses'

# Initialize AWS S3 client
s3 = Aws::S3::Client.new
PAGE_SIZE = 10 # Set the number of items to display per page

# Function to list objects in the current folder
def list_objects(s3, bucket, prefix = "")
  response = s3.list_objects_v2(bucket: bucket, prefix: prefix, delimiter: '/')

  # List folders with single trailing slash
  folders = response.common_prefixes.map { |prefix_obj| prefix_obj.prefix.gsub(prefix, '').chomp('/') + '/' }

  # List files
  files = response.contents.map { |obj| obj.key.gsub(prefix, "") }
  files.reject! { |f| f.include?("/") && f != prefix } # Remove subfolder items

  folders + files # Return folders and files in combined array
end

# Function to download a file
def download_file(s3, bucket, file_key, window)
  default_name = File.basename(file_key)
  window.setpos(Curses.lines - 3, 0)
  window.addstr("Enter a new name for the file or press Enter to keep '#{default_name}': ")
  Curses.curs_set(1)
  Curses.echo
  download_name = window.getstr.strip
  download_name = default_name if download_name.empty?
  Curses.noecho
  Curses.curs_set(0)
  s3.get_object(response_target: download_name, bucket: bucket, key: file_key)
  window.setpos(Curses.lines - 3, 0)
  window.addstr("Downloaded '#{download_name}'".ljust(Curses.cols))
  window.refresh
end

# Function to display the UI with pagination
def display_ui(window, bucket, prefix, items, page)
  window.clear

  # Calculate pagination boundaries
  start_index = page * PAGE_SIZE
  end_index = [start_index + PAGE_SIZE, items.size].min

  # Display current bucket path and contents with pagination info
  window.setpos(0, 0)
  window.addstr("Current Bucket: #{bucket} /#{prefix} (Page #{page + 1} of #{(items.size / PAGE_SIZE.to_f).ceil})")
  window.addstr("\nContents:\n")
  items[start_index...end_index].each_with_index do |item, index|
    window.addstr("[#{start_index + index}] #{item}\n")
  end

  # Bottom bar for options
  window.setpos(Curses.lines - 1, 0)
  window.attron(Curses::A_REVERSE) do # Reversed colors for bottom bar
    window.addstr("[H]: Help | [0-9]: Select item | [N]: New Bucket URL | [B]: Back | [P]: Prev Page | [F]: Next Page | [Q]: Quit".ljust(Curses.cols))
  end
  window.refresh
end

# Main navigation loop with pagination
def navigate_bucket(s3, bucket, window)
  prefix = ""
  history = []
  page = 0

  loop do
    items = list_objects(s3, bucket, prefix)
    display_ui(window, bucket, prefix, items, page) # Display the UI with updated contents

    # Input prompt (one line above the bottom options bar)
    window.setpos(Curses.lines - 3, 0)
    window.addstr("Input: ".ljust(Curses.cols))
    window.refresh
    Curses.curs_set(1) # Show cursor for input
    Curses.echo         # Enable input echoing
    input = window.getstr.strip.downcase
    Curses.noecho       # Disable input echoing after input is captured
    Curses.curs_set(0)  # Hide cursor

    case input
    when "q"
      break
    when "h"
      window.setpos(Curses.lines - 3, 0)
      window.addstr("Use [0-9] to select item, [Q] to quit, [N] to change bucket, [B] to go back, [P] to prev page, [F] to next page".ljust(Curses.cols))
      window.refresh
      window.getch
    when "n"
      window.setpos(Curses.lines - 3, 0)
      window.addstr("Enter new bucket name: ".ljust(Curses.cols))
      Curses.curs_set(1)
      Curses.echo
      bucket = window.getstr.strip
      Curses.noecho
      Curses.curs_set(0)
      prefix = ""
      history.clear
      page = 0
    when "b"
      prefix = history.pop || ""
      page = 0
    when "f"
      page += 1 if (page + 1) * PAGE_SIZE < items.size
    when "p"
      page -= 1 if page > 0
    when /^[0-9]+$/
      index = input.to_i
      if index >= 0 && index < items.size
        selected = items[index]
        new_prefix = "#{prefix}#{selected}".chomp('/')
        if selected.end_with?("/") # Folder
          history.push(prefix)
          prefix = "#{new_prefix}/"
          page = 0 # Reset to the first page in the new folder
        else # File
          download_file(s3, bucket, new_prefix, window)
        end
      end
    else
      window.setpos(Curses.lines - 3, 0)
      window.addstr("Invalid option. Press 'H' for help.".ljust(Curses.cols))
      window.refresh
      window.getch
    end
  end
end

# Start program
def main(s3)
  Curses.init_screen
  Curses.curs_set(0) # Hide cursor for full-screen mode
  Curses.noecho # Disable echoing of typed characters
  begin
    window = Curses.stdscr
    window.clear

    window.setpos(0, 0)
    window.addstr("Enter the S3 bucket name: ")
    Curses.curs_set(1)
    Curses.echo
    bucket = window.getstr.strip
    Curses.noecho
    Curses.curs_set(0)
    navigate_bucket(s3, bucket, window)
  ensure
    Curses.close_screen
  end
end

main(s3)
