#!/usr/bin/env ruby

class S3Helper
  def initialize(s3, ui, page_size)
    @s3 = s3
    @ui = ui
    @page_size = page_size
  end

  # Switch AWS region
  def switch_region
    regions = available_regions

    if regions.empty?
      @ui.display_info("No AWS regions available.")
      return
    end

    # Display regions for selection
    @ui.clear_info
    @ui.display_region_prompt(regions)
    input = @ui.prompt_user("Select a region by number: ").strip

    # Handle cancellation
    if input.downcase == 'q'
      @ui.display_info("Region selection cancelled.")
      return
    end

    index = input.to_i
    if index >= 0 && index < regions.size
      selected_region = regions[index]
      ENV['AWS_REGION'] = selected_region # Set the environment variable for the region
      @s3 = Aws::S3::Client.new(region: selected_region) # Reinitialize client with new region
      @ui.display_info("Switched to region '#{selected_region}'.")
    else
      @ui.display_info("Invalid region selection. Please try again.")
    end
  end

  # Fetch all available AWS regions, including GovCloud
  def available_regions
    partitions = %w[aws aws-us-gov]
    partitions.flat_map do |partition|
      Aws.partition(partition).regions.map(&:name)
    end.uniq
  end

  # List and switch AWS profiles
  def switch_profile
    credentials_path = File.expand_path(Aws::SharedCredentials.new.path)
    profiles = load_profiles(credentials_path)

    if profiles.empty?
      @ui.display_info("No profiles found in #{credentials_path}.")
      return
    end

    # Display profiles for selection
    @ui.clear_info
    @ui.display_profile_prompt(profiles)
    input = @ui.prompt_user("Select a profile by number: ").strip

    # Handle cancellation
    if input.downcase == 'q'
      @ui.display_info("Profile selection cancelled.")
      return
    end

    index = input.to_i
    if index >= 0 && index < profiles.size
      selected_profile = profiles[index]
      ENV['AWS_PROFILE'] = selected_profile # Set the environment variable for the profile
      @s3 = Aws::S3::Client.new # Reinitialize client with new profile
      @ui.display_info("Switched to profile '#{selected_profile}'. Press any key to continue.")
    else
      @ui.display_info("Invalid profile selection. Please try again.")
    end
  end

  # Load profiles from AWS credentials file
  def load_profiles(credentials_path)
    return [] unless File.exist?(credentials_path)

    # Parse profile names from the credentials file
    profiles = []
    File.foreach(credentials_path) do |line|
      if line.match(/^\[(.+?)\]/) # Match lines with [profile_name]
        profiles << Regexp.last_match(1)
      end
    end
    profiles
  end

  # Prompt user for a bucket and validate connection
  def select_bucket
    loop do
      @ui.clear_info
      @ui.display_bucket_prompt
      input = @ui.prompt_user("Enter a bucket name or option: ").strip.downcase

      case input
      when "q"
        exit # Quit the application
      when "p"
        switch_profile
      when "r"
        switch_region
      when "n"
        next
      else
        return input if connect_to_bucket(input) # Success, return bucket name
      end
    end
  end

  # Attempts to connect to the specified bucket to check accessibility
  def connect_to_bucket(bucket)
    begin
      # Attempt to list objects with an empty prefix to check access
      @s3.list_objects_v2(bucket: bucket, prefix: '', max_keys: 1)
      true # Connection successful, return true

    rescue Aws::S3::Errors::NoSuchBucket
      @ui.display_info("Bucket '#{bucket}' does not exist. Please check the name.")
      false
    rescue Aws::S3::Errors::InvalidBucketName
      @ui.display_info("Invalid bucket name format. Please enter a valid bucket name.")
      false
    rescue Aws::S3::Errors::AccessDenied
      @ui.display_info("Access denied to bucket '#{bucket}'. Check your permissions.")
      false
    rescue Seahorse::Client::NetworkingError
      @ui.display_info("Network error: Unable to connect to AWS S3. Check your connection.")
      false
    rescue Aws::S3::Errors::RequestTimeout
      @ui.display_info("Request timed out. The network may be slow. Try again later.")
      false
    rescue Aws::S3::Errors::Throttling
      @ui.display_info("Rate limit exceeded. Please wait a moment and try again.")
      false
    rescue StandardError => e
      @ui.display_info("An unexpected error occurred: #{e.message}")
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
      @ui.display_info("Downloaded '#{download_name}'.")
    rescue Aws::S3::Errors::NoSuchKey
      @ui.display_info("The file does not exist in the bucket.")
    rescue Aws::S3::Errors::AccessDenied
      @ui.display_info("Access denied. You do not have permission to download this file.")
    rescue Seahorse::Client::NetworkingError
      @ui.display_info("Network error: Unable to download file. Check your connection and try again.")
    rescue StandardError => e
      @ui.display_info("An unexpected error occurred: #{e.message}")
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
        @ui.display_info("No items to display in this folder.")
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
        @ui.display_info("Invalid option. Press 'H' for help.")
      end
    end
  end
end
