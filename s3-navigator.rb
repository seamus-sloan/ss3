require 'aws-sdk-s3'

# The S3Navigator class handles the interaction with the AWS S3 SDK.
# Any interactions with the AWS S3 SDK should be handlded through this class including providing
# options to display to the user via another class (i.e. UINavigator).
class S3Navigator
  # Creates an instance of the S3Navigator class.
  #
  # @param bucket_name [String] Optional. The name of the bucket if already known at runtime.
  def initialize(bucket_name)
    @bucket_name = bucket_name || nil
    @current_path = [""]
    @status = :success

    begin
      @s3_client = Aws::S3::Client.new
    rescue Aws::Errors::MissingRegionError => e
      @status = :error
    end
  end

  def status
    return @status
  end

  # Returns the current ENV['AWS_REGION'] value or an empty string.
  def current_region
    return @s3_client.config.region || ""
  end

  # Returns all available AWS regions.
  def regions
    partitions = %w[aws aws-us-gov]
    partitions.flat_map do |partition|
      Aws.partition(partition).regions.map(&:name)
    end.uniq
  end

  # Updates the current region with the provided one.
  #
  # @param region [String] Name of the region
  def change_region(region)
    @s3_client = Aws::S3::Client.new(region:)
  end

  # Returns the current ENV['AWS_PROFILE'] value or an empty string.
  def current_profile
    profile_name = ""
    begin
      credentials = @s3_client.config.credentials
      profile_name = credentials.profile_name
    rescue
      # TODO: Investigate how to handle a case where credentials aren't set (i.e. no default)
    end
    profile_name
  end

  # Returns all available AWS profiles from '~/.aws/credentials'.
  def profiles
    profile_names = []

    # Gather the credentials from ./aws/credentials or similar
    begin
      credentials_path = File.expand_path(Aws::SharedCredentials.new.path)
      return {status: :error, message: "No credential path found. Ensure aws cli is installed & run `aws configure`."} unless File.exist?(credentials_path)
    rescue Aws::Errors::NoSuchProfileError
      return {status: :error, message: "No default profile set. Please run `aws configure` outside of this script."}
    end
    # Parse profiles by matching for [profile_name] in the file
    File.foreach(credentials_path) do |line|
      if line.match(/^\[(.+?)\]/)
        profile_names << Regexp.last_match(1)
      end
    end

    return {status: :success, data: profile_names}
  end

  # Updates the current profile with the provided one.
  #
  # @param profile [String] Name of the profile
  def change_profile(profile)
    ENV['AWS_PROFILE'] = profile
    @s3_client = Aws::S3::Client.new
  end

  # Returns the current bucket name.
  def bucket_name
    @bucket_name
  end

  # Updates the bucket name with the provided one.
  #
  # @param name [String] Name of the bucket
  def change_bucket_name(name)
    @bucket_name = name
  end

  # Returns a list of folders & files within the current folder of the bucket.
  def list_items
    prefix = @current_path.last
    begin
      response = @s3_client.list_objects_v2(bucket: @bucket_name, prefix: prefix, delimiter: '/')
      
      # Collect folders with their last modified dates
      folders = response.common_prefixes.map do |prefix_obj|
        folder_name = prefix_obj.prefix.gsub(prefix, '').chomp('/') + '/'
        folder_prefix = prefix_obj.prefix

        # Fetch objects within the folder to determine last modified date
        folder_response = @s3_client.list_objects_v2(bucket: @bucket_name, prefix: folder_prefix)
        folder_last_modified = folder_response.contents.map(&:last_modified).max

        { name: folder_name, last_modified: folder_last_modified }
      end

      # Collect files with their last modified dates
      files = response.contents.map do |obj|
        file_name = obj.key.gsub(prefix, "")
        { name: file_name, last_modified: obj.last_modified }
      end

      # Reject any deeper path items for the current level
      files.reject! { |f| f[:name].include?("/") && f[:name] != prefix }

      # Combine and sort folders and files by last modified date
      items = folders + files
      items.sort_by! { |item| item[:last_modified] || Time.at(0) }.reverse!

      # Return success with the items
      return { status: :success, data: items }
    
    rescue Aws::Errors::MissingCredentialsError => e
      # Handle missing credentials error
      return { status: :error, message: "Missing AWS credentials: #{e.message}" }
    rescue Aws::S3::Errors::ServiceError => e
      # Handle AWS S3 service errors
      return { status: :error, message: "AWS S3 error: #{e.message}" }
    rescue StandardError => e
      # Handle any other exceptions
      return { status: :error, message: "An unexpected error occurred: #{e.message}" }
    end
  end

  # Downloads the selected file to the current directory.
  def download_file(download_name, file_name)
    key = File.join(@current_path.last, file_name)
    @s3_client.get_object(response_target: download_name, bucket: @bucket_name, key: key)
  end

  # Returns true or false if the current path is the root of the bucket.
  def is_at_root
    return @current_path.count == 1
  end

  # Returns the current path in the bucket.
  def current_path
    @current_path.last
  end

  # Clears all historical paths from bucket traversal
  def clear_history
    @current_path = [""]
  end

  # Updates the current path such that the current path is back one step.
  def go_back
    @current_path.pop
  end

  # Navigates into a folder by setting the current path to the new folder path.
  #
  # @param folder_name [String] Name of the new folder
  def enter_folder(folder_name)
    @current_path.push("#{@current_path.last}#{folder_name}")
  end
end
