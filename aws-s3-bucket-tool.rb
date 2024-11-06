#!/usr/bin/env ruby

require 'aws-sdk-s3'
require 'tty-prompt'
require 'tty-reader'
require 'tty-screen'
require 'fileutils'

# Initialize AWS S3 client and TTY tools
s3 = Aws::S3::Client.new
prompt = TTY::Prompt.new
reader = TTY::Reader.new

# Function to list objects with indexes in the current folder
def list_objects(s3, bucket, prefix = "")
  response = s3.list_objects_v2(bucket: bucket, prefix: prefix, delimiter: '/')

  # List folders with single trailing slash
  folders = response.common_prefixes.map { |prefix_obj| prefix_obj.prefix.gsub(prefix, '').chomp('/') + '/' }

  # List files
  files = response.contents.map { |obj| obj.key.gsub(prefix, "") }
  files.reject! { |f| f.include?("/") && f != prefix } # Remove subfolder items

  items = folders + files
  items.each_with_index { |item, index| puts "[#{index}] #{item}" }
  items
end

# Function to download a file
def download_file(s3, prompt, bucket, file_key)
  default_name = File.basename(file_key)
  download_name = prompt.ask("Enter a new name for the file or press Enter to keep '#{default_name}':", default: default_name)
  s3.get_object(response_target: download_name, bucket: bucket, key: file_key)
  puts "Downloaded '#{download_name}'"
end

# Main navigation loop
def navigate_bucket(s3, prompt, reader, bucket)
  prefix = ""
  history = []

  loop do
    system "clear" # Clear screen for each navigation step
    puts "Current Bucket: #{bucket} /#{prefix}"
    items = list_objects(s3, bucket, prefix)
    puts "\n[H]: Help | [0-9]: Select | [Q]: Quit | [N]: New Bucket URL | [B]: Back"
    print "Input: "
    input = reader.read_line.strip

    case input.downcase
    when "q"
      puts "Exiting..."
      break
    when "h"
      puts "Help: [0-9] - Select item, [Q] - Quit, [N] - New Bucket URL, [B] - Go Back"
      sleep(2)
    when "n"
      bucket = prompt.ask("Enter new bucket name:")
      prefix = ""
      history.clear
    when "b"
      prefix = history.pop || ""
    when /^[0-9]+$/
      index = input.to_i
      if index < items.size
        selected = items[index]
        new_prefix = "#{prefix}#{selected}".chomp('/')
        if selected.end_with?("/") # Folder
          history.push(prefix)
          prefix = "#{new_prefix}/"
        else # File
          download_file(s3, prompt, bucket, new_prefix) # Pass prompt argument here
        end
      end
    else
      puts "Invalid option. Press 'H' for help."
      sleep(2)
    end
  end
end

# Start program
def main(s3, prompt, reader)
  bucket = prompt.ask("Enter the S3 bucket name:")
  navigate_bucket(s3, prompt, reader, bucket)
end

main(s3, prompt, reader)
