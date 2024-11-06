#!/usr/bin/env ruby

class S3Browser
  def initialize(s3, ui, page_size)
    @s3 = s3
    @ui = ui
    page_size = page_size
  end

  # Attempts to connect to the specified bucket to check accessibility
  def connect_to_bucket(bucket)
    begin
      # Attempt to list objects with an empty prefix to check access
      @s3.list_objects_v2(bucket: bucket, prefix: '', max_keys: 1)
      true # Connection successful, return true

    rescue Aws::S3::Errors::NoSuchBucket
      @ui.display_error("Bucket '#{bucket}' does not exist. Please check the name.")
      false
    rescue Aws::S3::Errors::InvalidBucketName
      @ui.display_error("Invalid bucket name format. Please enter a valid bucket name.")
      false
    rescue Aws::S3::Errors::AccessDenied
      @ui.display_error("Access denied to bucket '#{bucket}'. Check your permissions.")
      false
    rescue Seahorse::Client::NetworkingError
      @ui.display_error("Network error: Unable to connect to AWS S3. Check your connection.")
      false
    rescue Aws::S3::Errors::RequestTimeout
      @ui.display_error("Request timed out. The network may be slow. Try again later.")
      false
    rescue Aws::S3::Errors::Throttling
      @ui.display_error("Rate limit exceeded. Please wait a moment and try again.")
      false
    rescue StandardError => e
      @ui.display_error("An unexpected error occurred: #{e.message}")
      false
    end
  end

  # List objects in the current bucket folder.
  def list_objects(bucket, prefix = "")
    response = @s3.list_objects_v2(bucket: bucket, prefix: prefix, delimiter: '/')
    folders = response.common_prefixes.map { |prefix_obj| prefix_obj.prefix.gsub(prefix, '').chomp('/') + '/' }
    files = response.contents.map { |obj| obj.key.gsub(prefix, "") }
    files.reject! { |f| f.include?("/") && f != prefix }

    folders + files
  end

  # Download a file and confirm to the user.
  def download_file(bucket, file_key)
    default_name = File.basename(file_key)
    prompt = "Enter a new name for the file or press Enter to keep '#{default_name}': "
    download_name = @ui.prompt_user(prompt)
    download_name = default_name if download_name.empty?

    begin
      @s3.get_object(response_target: download_name, bucket: bucket, key: file_key)
      @ui.display_error("Downloaded '#{download_name}'.")
    rescue Aws::S3::Errors::NoSuchKey
      @ui.display_error("The file does not exist in the bucket.")
    rescue Aws::S3::Errors::AccessDenied
      @ui.display_error("Access denied. You do not have permission to download this file.")
    rescue Seahorse::Client::NetworkingError
      @ui.display_error("Network error: Unable to download file. Check your connection and try again.")
    rescue StandardError => e
      @ui.display_error("An unexpected error occurred: #{e.message}")
    end
  end

  # Navigate within the bucket and interact with files.
  def navigate_bucket(bucket)
    path = "" # The current path in the bucket
    history = [] # History of bucket traversal paths
    page = 0 # Current page when pagination is active

    loop do
      items = list_objects(bucket, path)
      return if items.nil?

      if items.empty?
        @ui.display_error("No items to display in this folder.")
        return
      end

      @ui.display_page(bucket, path, items, page)
      input = @ui.prompt_user("Input: ").downcase

      case input
      when "q" then break
      when "h" then @ui.display_help
      when "n"
        return :restart # Signal to break out of this loop & restart
      when "b"
        path = history.pop || ""
        page = 0
      when "f"
        page += 1 if (page + 1) * @page_size < items.size
      when "p"
        page -= 1 if page > 0
      when /^[0-9]+$/
        index = input.to_i
        if index >= 0 && index < items.size
          selected = items[index]
          new_path = "#{path}#{selected}".chomp('/')
          if selected.end_with?("/") # Folder
            history.push(path)
            path = "#{new_path}/"
            page = 0
          else # File
            download_file(bucket, new_path)
          end
        end
      else
        @ui.display_error("Invalid option. Press 'H' for help.")
      end
    end
  end
end
