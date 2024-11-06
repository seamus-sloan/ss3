#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'curses'

PAGE_SIZE = 20 # Number of items per page

# Prompt the user with a message & return their stripped input.
def inputHelper(window, prompt)
  window.setpos(Curses.lines - 3, 0)
  window.addstr(prompt)

  Curses.curs_set(1)
  Curses.echo
  value = window.getstr.strip
  Curses.noecho
  Curses.curs_set(0)

  value
end

# Function to list objects in the current folder
def list_objects(s3, bucket, prefix = "")
  response = s3.list_objects_v2(bucket: bucket, prefix: prefix, delimiter: '/')

  # List folders with single trailing slash
  folders = response.common_prefixes.map { |prefix_obj| prefix_obj.prefix.gsub(prefix, '').chomp('/') + '/' }

  # List files
  files = response.contents.map { |obj| obj.key.gsub(prefix, "") }
  files.reject! { |f| f.include?("/") && f != prefix } # Remove subfolder items

  folders + files
end

# Function to download a file.
def download_file(s3, bucket, file_key, window)
  # Gather the file name & prompt for a new name if desired.
  default_name = File.basename(file_key)
  prompt = "Enter a new name for the file or press Enter to keep '#{default_name}': "
  download_name = inputHelper(window, prompt)
  download_name = default_name if download_name.empty?

  # Download the file
  s3.get_object(response_target: download_name, bucket: bucket, key: file_key)

  # Show the downloaded confirmation message
  window.setpos(Curses.lines - 3, 0)
  window.addstr("Downloaded '#{download_name}'. Press any key to continue.".ljust(Curses.cols))
  window.refresh
  window.getch
end

# Function to display the UI with pagination
def display_ui(window, bucket, prefix, items, page)
  window.clear

  # Calculate pagination boundaries
  start_index = page * PAGE_SIZE
  end_index = [start_index + PAGE_SIZE, items.size].min

  # Display current bucket path and contents with pagination info
  page_count = (items.size / PAGE_SIZE.to_f).ceil
  window.setpos(0, 0)
  window.addstr("Current Bucket: #{bucket} /#{prefix} (Page #{page + 1} of #{page_count})")
  window.addstr("\nContents:\n")
  items[start_index...end_index].each_with_index do |item, index|
    window.addstr("[#{start_index + index}] #{item}\n")
  end

  window.addstr("\n")
  if page == 0 && page_count > 1
    window.addstr("Press 'F' for next page.")
  elsif page + 1 == page_count && page_count > 1
    window.addstr("Press 'P' for previous page.")
  elsif page != 0 && page_count > 1
    window.addstr("Press 'P' for previous page. Press 'F' for next page.")
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
    display_ui(window, bucket, prefix, items, page)
    input = inputHelper(window, "Input: ").downcase

    case input
    when "q"
      break
    when "h"
      window.setpos(Curses.lines - 14, 0)
      window.addstr("
        [0-9] to select item\n
        [Q] to quit\n
        [N] to change bucket\n
        [B] to go back\n
        [P] to prev page\n
        [F] to next page"
      .ljust(Curses.cols))
      window.refresh
      window.getch
    when "n"
      bucket = inputHelper(window, "Enter new bucket name: ")
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
      window.setpos(Curses.lines - 4, 0)
      window.addstr("Invalid option. Press 'H' for help.".ljust(Curses.cols))
      window.refresh
      window.getch
    end
  end
end

# Start program
def main(s3)
  Curses.init_screen
  Curses.curs_set(0)
  Curses.noecho
  begin
    window = Curses.stdscr
    window.clear
    bucket = inputHelper(window, "Enter the S3 bucket name: ")
    navigate_bucket(s3, bucket, window)
  ensure
    Curses.close_screen
  end
end

s3 = Aws::S3::Client.new
main(s3)
