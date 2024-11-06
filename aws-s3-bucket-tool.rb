#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'curses'

PAGE_SIZE = 20 # Number of items per page

class S3Browser
  def initialize(s3, window)
    @s3 = s3
    @window = window
  end

  # Prompt the user with a message & return their input.
  def prompt_user(prompt)
    @window.setpos(Curses.lines - 3, 0)
    @window.addstr(prompt)

    Curses.curs_set(1)
    Curses.echo
    input = @window.getstr.strip
    Curses.noecho
    Curses.curs_set(0)

    input
  end

  # Display an error message above the input line.
  def display_error(message)
    @window.setpos(Curses.lines - 5, 0)
    @window.addstr(message.ljust(Curses.cols))
    @window.addstr("Press any key to continue.")
    @window.refresh
    @window.getch
  end

  # Clears the line(s)
  def clear_lines(lines)
    for line in lines
      @window.setpos(line, 0)
      @window.addstr(" " * Curses.cols) # Clear error line
    end
  end

  # List objects in the current bucket folder.
  def list_objects(bucket, prefix = "")
    begin
      response = @s3.list_objects_v2(bucket: bucket, prefix: prefix, delimiter: '/')
      folders = response.common_prefixes.map { |prefix_obj| prefix_obj.prefix.gsub(prefix, '').chomp('/') + '/' }
      files = response.contents.map { |obj| obj.key.gsub(prefix, "") }
      files.reject! { |f| f.include?("/") && f != prefix }
    rescue Aws::S3::Errors::NoSuchBucket
      display_error("Bucket does not exist. Check your spelling and try again.")
      return nil
    rescue StandardError => e
      display_error("An error occurred: #{e.message}")
      return nil
    end

    folders + files
  end

  # Download a file and confirm to the user
  def download_file(bucket, file_key)
    default_name = File.basename(file_key)
    prompt = "Enter a new name for the file or press Enter to keep '#{default_name}': "
    download_name = prompt_user(prompt)
    download_name = default_name if download_name.empty?

    @s3.get_object(response_target: download_name, bucket: bucket, key: file_key)
    @window.setpos(Curses.lines - 3, 0)
    @window.addstr("Downloaded '#{download_name}'. Press any key to continue.".ljust(Curses.cols))
    @window.refresh
    @window.getch
  end

  # Render UI with pagination
  def display_page(bucket, prefix, items, page)
    @window.clear
    start_index = page * PAGE_SIZE
    end_index = [start_index + PAGE_SIZE, items.size].min
    page_count = (items.size / PAGE_SIZE.to_f).ceil

    # Display bucket path, contents, and pagination info
    @window.setpos(0, 0)
    @window.addstr("Current Bucket: #{bucket} /#{prefix} (Page #{page + 1} of #{page_count})\nContents:\n")
    items[start_index...end_index].each_with_index { |item, index| @window.addstr("[#{start_index + index}] #{item}\n") }

    # Display page navigation prompts
    @window.addstr("\n")
    @window.addstr(if page == 0 && page_count > 1
                     "(Press 'F' for next page.)"
                   elsif page + 1 == page_count && page_count > 1
                     "(Press 'P' for previous page.)"
                   elsif page_count > 1
                     "(Press 'P' for previous page. Press 'F' for next page.)"
                   end.to_s)

    # Options bar
    @window.setpos(Curses.lines - 1, 0)
    @window.attron(Curses::A_REVERSE) do
      @window.addstr("[H]: Help | [0-9]: Select item | [N]: New Bucket URL | [B]: Back | [P]: Prev Page | [F]: Next Page | [Q]: Quit".ljust(Curses.cols))
    end
    @window.refresh
  end

  # Navigate within the bucket and interact with files
  def navigate_bucket(bucket)
    prefix = ""
    history = []
    page = 0

    loop do
      items = list_objects(bucket, prefix)
      return if items.nil? # Exit if there was an error listing objects
      display_page(bucket, prefix, items, page)
      input = prompt_user("Input: ").downcase

      case input
      when "q" then break
      when "h" then display_help
      when "n"
        bucket = prompt_user("Enter new bucket name: ")
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
            page = 0
          else # File
            download_file(bucket, new_prefix)
          end
        end
      else
        @window.setpos(Curses.lines - 4, 0)
        @window.addstr("Invalid option. Press 'H' for help.".ljust(Curses.cols))
        @window.refresh
        @window.getch
      end
    end
  end

  # Display help information
  def display_help
    help_text = "
      [0-9] to select item
      [Q] to quit
      [N] to change bucket
      [B] to go back
      [P] to prev page
      [F] to next page
      Press any key to continue..."
    @window.setpos(Curses.lines - (help_text.lines.count + 3), 0)
    @window.addstr(help_text.ljust(Curses.cols))
    @window.refresh
    @window.getch
  end
end

# Main function to initialize Curses and start navigation
def main(s3)
  Curses.init_screen
  Curses.curs_set(0)
  Curses.noecho
  begin
    window = Curses.stdscr
    window.clear
    browser = S3Browser.new(s3, window)

    # Loop to prompt for a valid bucket name until successful
    bucket = nil
    loop do
      browser.clear_lines(Curses.lines - 5 .. Curses.lines - 3)
      bucket = browser.prompt_user("Enter the S3 bucket name: ")

      # Break if valid bucket, otherwise display error
      break if !browser.list_objects(bucket).nil?
    end

    browser.navigate_bucket(bucket)
  ensure
    Curses.close_screen
  end
end

s3 = Aws::S3::Client.new
main(s3)
