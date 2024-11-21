require 'cli/ui'

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

  def help
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
    options << { name: "👤 Change AWS Profile (Current: #{current_profile})", action: -> { change_aws_profile } }

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
    # Profiles will return :error or :success as [0]
    profiles = @s3_navigator.profiles

    if profiles[:status] == :success
      CLI::UI::Prompt.ask("Select a new profile: (Current: #{@s3_navigator.current_profile})") do |handler|
        profiles[:data].each do |profile|
          handler.option(profile) { @s3_navigator.change_profile(profile) }
        end
      end
    else
      CLI::UI::Frame.open("Error Loading Profiles", color: :red) do
        CLI::UI::Prompt.ask(profiles[:message]) do |handler|
          handler.option("Back to Main Menu") { nil } # Return nil to indicate that we need to display the main menu again.
          handler.option("Exit") { :exit} # Return :exit to the main function to indicate that the program should exit.
        end
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
        action_result = nil  # Used to determine next step within the loop
        result = nil # The result from attempting to list items from S3
        
        # Show a spinner while items are loading.
        CLI::UI::Spinner.spin("Loading items...") do |spinner|
          result = @s3_navigator.list_items
        end

        # If we get an error while fetching the items, display the error.
        if result[:status] != :success
          error_message = result[:message]
          puts CLI::UI.fmt(
            "{{red:Failed to load items.}}\n{{red:Error: #{error_message}}}\n\n{{red:Returning to main menu...}}"
          )
          action_result = :back_to_main_menu
        
          # If there's no error, display normal behavior
        else
          items = result[:data]  
          total_pages = (items.size / page_size.to_f).ceil
          options = bucket_options(items, page_size: page_size, page: page)
  
          CLI::UI::Prompt.ask("Select an option (Page #{page}/#{total_pages}): ") do |handler|
            options.each do |option|
              handler.option(option[:name]) do
                action_result = option[:action].call  # Capture the action's result
              end
            end
          end
        end

        case action_result
        when :enter_folder
          page = 1  # Reset page when entering a new folder
          result = bucket_navigation  # Capture the return value
          return result if result == :back_to_main_menu  # Propagate if necessary
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
          # Continue the loop here...
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
          download_item(item)
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

  # Display options for downloading a file
  def download_item(item)
    CLI::UI::Frame.open("Download #{item[:name]}", color: :magenta) do
      puts "This item will be downloaded to the current directory."
      name = CLI::UI::Prompt.ask("Enter a new name for the file: ", default: item[:name])
      @s3_navigator.download_file(name, item[:name])
    end
  end
end
