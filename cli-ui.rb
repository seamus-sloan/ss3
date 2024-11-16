require 'aws-sdk-s3'
require 'cli/ui'

# The S3Navigator class handles the interaction with the AWS S3 SDK.
# Any interactions with the AWS S3 SDK should be handlded through this class including providing
# options to display to the user via another class (i.e. UINavigator).
class S3Navigator
  # Creates an instance of the S3Navigator class.
  #
  # @param bucket_name [String] Optional. The name of the bucket if already known at runtime.
  def initialize(bucket_name)
    @bucket_name = bucket_name || nil
    @s3_client = Aws::S3::Client.new
    @current_path = [""]
  end

  # Returns the current ENV['AWS_REGION'] value or an empty string.
  def current_region
    return ENV['AWS_REGION'] || ""
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
    ENV['AWS_REGION'] = region
    @s3_client = Aws::S3::Client.new(region:)
  end

  # Returns the current ENV['AWS_PROFILE'] value or an empty string.
  def current_profile
    return ENV['AWS_PROFILE'] || ""
  end

  # Returns all available AWS profiles from '~/.aws/credentials'.
  def profiles
    profile_names = []

    # Gather the credentials from ./aws/credentials or similar
    credentials_path = File.expand_path(Aws::SharedCredentials.new.path)
    return profile_names unless File.exist?(credentials_path)

    # Parse profiles by matching for [profile_name] in the file
    File.foreach(credentials_path) do |line|
      if line.match(/^\[(.+?)\]/)
        profile_names << Regexp.last_match(1)
      end
    end

    profile_names
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

    items
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










# The UINavigator class handles the user interface navigation for the S3 bucket explorer.
# It manages the main menu and bucket navigation, providing options for the user to interact
# with AWS S3 buckets and their contents using a command-line interface.
class UINavigator
  # Initializes the UINavigator with an instance of S3Navigator.
  #
  # @param s3_navigator [S3Navigator] An instance of S3Navigator to interact with AWS S3.
  def initialize(s3_navigator)
    CLI::UI::StdoutRouter.enable
    @s3_navigator = s3_navigator
  end

  # Starts the main loop of the user interface, displaying the main menu and handling user input.
  # This method runs indefinitely until the user chooses to exit the application.
  def start
    loop do
      result = show_main_menu
      case result
      when :exit
        exit 0
      when :bucket_navigation
        bucket_navigation
        # After returning from bucket_navigation, loop back to show_main_menu
      end
    end
  end

  # Displays the main menu within a CLI frame and handles user selections.
  #
  # @return [Symbol, nil] Returns a symbol indicating the next action (:exit, :bucket_navigation),
  #   or nil to continue displaying the main menu.
  def show_main_menu
    action_result = nil

    CLI::UI::Frame.open("Main Menu", color: :green) do
      CLI::UI::Prompt.ask("SS3 Main Menu Option: ") do |handler|
        main_menu_options.each do |option|
          handler.option(option[:name]) do
            action_result = option[:action].call
          end
        end
      end
    end

    action_result
  end

  # Generates the list of options for the main menu.
  #
  # @return [Array<Hash>] An array of hashes representing the menu options and their associated actions.
  def main_menu_options
    options = []
    current_region = @s3_navigator.current_region.empty? ? "NOT SET" : @s3_navigator.current_region
    current_profile = @s3_navigator.current_profile.empty? ? "NOT SET" : @s3_navigator.current_profile

    options << { name: "🌎 Change AWS Region (Current: #{current_region})", action: -> { change_aws_region; nil } }
    options << { name: "👤 Change AWS Profile (Current: #{current_profile})", action: -> { change_aws_profile; nil } }

    if @s3_navigator.bucket_name.nil?
      options << { name: "🪣 Enter Bucket Name", action: -> { enter_bucket_name; nil } }
    else
      options << { name: "🪣 Change Bucket Name", action: -> { update_bucket_name(@s3_navigator.bucket_name); nil } }
      options << { name: "📂 Enter '#{@s3_navigator.bucket_name}'", action: -> { :bucket_navigation } }
    end

    options << { name: "❌ Quit", action: -> { :exit } }

    options
  end

  # Prompts the user to select a new AWS region from the available regions.
  # Updates the S3Navigator with the selected region.
  def change_aws_region
    regions = @s3_navigator.regions
    CLI::UI::Prompt.ask("Select a new region: (Current: #{@s3_navigator.current_region})") do |handler|
      regions.each do |region|
        handler.option(region) { @s3_navigator.change_region(region) }
      end
    end
  end

  # Prompts the user to select a new AWS profile from the available profiles.
  # Updates the S3Navigator with the selected profile.
  def change_aws_profile
    profiles = @s3_navigator.profiles
    CLI::UI::Prompt.ask("Select a new profile: (Current: #{@s3_navigator.current_profile})") do |handler|
      profiles.each do |profile|
        handler.option(profile) { @s3_navigator.change_profile(profile) }
      end
    end
  end

  # Prompts the user to enter the name of an S3 bucket to interact with.
  # Updates the S3Navigator with the entered bucket name.
  def enter_bucket_name
    bucket_name = CLI::UI::Prompt.ask("Enter the name of the bucket: ")
    @s3_navigator.change_bucket_name(bucket_name)
  end

  # Prompts the user to update the current S3 bucket name.
  #
  # @param bucket_name [String] The current bucket name to be displayed as the default.
  def update_bucket_name(bucket_name)
    updated_name = CLI::UI::Prompt.ask("Enter a new bucket name: ", default: bucket_name)
    @s3_navigator.change_bucket_name(updated_name)
  end

  # Manages the navigation within an S3 bucket, allowing the user to explore folders and files.
  # This method handles user input for navigating into folders, going back, and returning to the main menu.
  def bucket_navigation
    page = 1
    page_size = 15

    CLI::UI::Frame.open("#{@s3_navigator.bucket_name}/#{@s3_navigator.current_path}") do
      loop do
        action_result = nil  # Initialize the action result variable

        # Add spinner while loading items
        items = nil
        begin
          CLI::UI::Spinner.spin("Loading items...") do
            items = @s3_navigator.list_items
          end
        rescue Aws::S3::Errors::ServiceError => e
          puts CLI::UI.fmt("{{x}} Failed to load items: #{e.message}")
          action_result = :back_to_main_menu
        end

        # Handle error case
        if items.nil?
          return :back_to_main_menu if action_result == :back_to_main_menu
          next  # Skip to the next loop iteration
        end

        total_pages = (items.size / page_size.to_f).ceil
        options = bucket_options(items, page_size: page_size, page: page)

        CLI::UI::Prompt.ask("Select an option (Page #{page}/#{total_pages}): ") do |handler|
          options.each do |option|
            handler.option(option[:name]) do
              action_result = option[:action].call  # Capture the action's result
            end
          end
        end

        case action_result
        when :enter_folder
          page = 1  # Reset page when entering a new folder
          bucket_navigation
        when :go_back
          @s3_navigator.go_back
          return
        when :back_to_main_menu
          @s3_navigator.clear_history
          return :back_to_main_menu
        when :next_page
          if page < total_pages
            page += 1
          else
            puts "You are on the last page."
          end
        when :previous_page
          if page > 1
            page -= 1
          else
            puts "You are on the first page."
          end
        else
          # Continue the loop for other actions
        end
      end
    end
  end


  # Generates the list of options for navigating within a bucket.
  #
  # @return [Array<Hash>] An array of hashes representing the navigation options and their associated actions.
  def bucket_options(items, page_size: 15, page: 1)
    total_pages = (items.size / page_size.to_f).ceil
    paginated_items = items.slice((page - 1) * page_size, page_size) || []
    options = []

    # Add navigation options
    options << { name: "Go Back", action: -> { :go_back } } unless @s3_navigator.is_at_root

    # Add items for the current page
    paginated_items.each do |item|
      last_modified_str = item[:last_modified]&.strftime('%Y-%m-%d %H:%M:%S') || ''
      item_icon = item[:name].end_with?('/') ? '📁' : '📄'
      display_name = "#{item_icon} #{item[:name]} - #{last_modified_str}"

      action = if item[:name].end_with?('/')
        -> {
          @s3_navigator.enter_folder(item[:name])
          :enter_folder
        }
      else
        -> {
          @s3_navigator.download_file(item)
          nil  # Continue the loop after downloading
        }
      end

      options << { name: display_name, action: action }
    end

    # Add pagination controls if necessary
    if total_pages > 1
      options << { name: "⬅️ Previous Page", action: -> { :previous_page } } if page > 1
      options << { name: "➡️ Next Page", action: -> { :next_page } } if page < total_pages
    end

    options << { name: "❌ Back to Main Menu", action: -> { :back_to_main_menu } }

    options
  end
end



if ARGV.any? { |arg| ["--help", "-h"].include?(arg) }
  CLI::UI::Frame.open("SS3 HELP") do
    puts <<-Help
      Usage: ss3 [OPTIONS]

      Options:
        --help, -h \t Show this help message.
        bucket_name\t Immediately provide the S3 bucket name.

      Description:
        This script allows you to explore an S3 bucket and modify
        files within a bucket without having to memorize AWS CLI
        commands.

        For the best results, ensure that AWS_REGION and AWS_PROFILE
        are set in your terminal and that you have ran `aws configure`
        at least once on your machine.

      Examples:
        ss3
        ss3 my-super-secret-bucket-name
      Help
    exit
  end
end


begin
  s3_navigator = S3Navigator.new(ARGV[0])
  ui_navigator = UINavigator.new(s3_navigator)
  ui_navigator.start
rescue Interrupt
  puts "\nExiting..."
  exit 0
end
