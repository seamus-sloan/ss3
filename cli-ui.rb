require 'aws-sdk-s3'
require 'cli/ui'

class S3Navigator
  def initialize(bucket_name)
    @bucket_name = bucket_name || nil
    @s3_client = Aws::S3::Client.new
    @current_path = [""]
  end

  def current_region
    return ENV['AWS_REGION'] || ""
  end

  def regions
    partitions = %w[aws aws-us-gov]
    partitions.flat_map do |partition|
      Aws.partition(partition).regions.map(&:name)
    end.uniq
  end

  def change_region(region)
    ENV['AWS_REGION'] = region
    @s3_client = Aws::S3::Client.new(region:)
  end

  def current_profile
    return ENV['AWS_PROFILE'] || ""
  end

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

  def change_profile(profile)
    ENV['AWS_PROFILE'] = profile
    @s3_client = Aws::S3::Client.new
  end

  def bucket_name
    @bucket_name
  end

  def change_bucket_name(name)
    @bucket_name = name
  end

  def current_path
    @current_path.last
  end

  def list_items
    prefix = @current_path.last
    response = @s3_client.list_objects_v2(bucket: @bucket_name, prefix: prefix, delimiter: '/')

    # Collect folders and files with timestamps
    folders = response.common_prefixes.map { |prefix_obj| { name: prefix_obj.prefix.gsub(prefix, '').chomp('/') + '/', last_modified: nil } }
    files = response.contents.map { |obj| { name: obj.key.gsub(prefix, ""), last_modified: obj.last_modified } }

    # Reject any items with deeper paths (for current prefix level only)
    files.reject! { |f| f[:name].include?("/") && f[:name] != prefix }

    files.sort_by { |file| [file[:last_modified] ? 1 : 0, file[:last_modified] || Time.at(0)] }.reverse

    {folders: folders, files: files}
  end

  def is_at_root
    return @current_path.count == 1
  end

  def go_back
    @current_path.pop
  end

  def enter_folder(folder_name)
    @current_path.push("#{@current_path.last}#{folder_name}")
  end

end










class UINavigator
  def initialize(s3_navigator)
    @s3_navigator = s3_navigator
  end

  def start
    loop do
      result = show_main_menu
      case result
      when :exit
        exit 0
      when :bucket_navigation
        bucket_navigation
      end
    end
  end

  def show_main_menu
    CLI::UI::Frame.open("Main Menu") do
      CLI::UI::Prompt.ask("SS3 Main Menu Option: ") do |handler|
        main_menu_options.each do |option|
          handler.option(option[:name]) { return option[:action].call }
        end
      end
    end
  end

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

  def change_aws_region
    regions = @s3_navigator.regions
    CLI::UI::Prompt.ask("Select a new profile: (current: #{@s3_navigator.current_region})") do |handler|
      regions.each do |region|
        handler.option(region) { @s3_navigator.change_region(region)}
      end
    end
  end

  def change_aws_profile
    profiles = @s3_navigator.profiles
    CLI::UI::Prompt.ask("Select a new profile: (current: #{@s3_navigator.current_profile})") do |handler|
      profiles.each do |profile|
        handler.option(profile) { @s3_navigator.change_profile(profile)}
      end
    end
  end

  def enter_bucket_name
    bucket_name = CLI::UI::Prompt.ask("Enter the name of the bucket: ")
    @s3_navigator.change_bucket_name(bucket_name)
  end

  def update_bucket_name(bucket_name)
    updated_name = CLI::UI::Prompt.ask("Enter a new name bucket name: ", default: bucket_name)
    @s3_navigator.change_bucket_name(updated_name)
  end

  def bucket_navigation
    loop do
      result = show_bucket_menu
      break if result == :back_to_main_menu
    end
  end

  def show_bucket_menu
    CLI::UI::Frame.open("Bucket Navigation") do
      CLI::UI::Frame.open("#{@s3_navigator.bucket_name}/#{@s3_navigator.current_path}") do
        CLI::UI::Prompt.ask("Select an option: ") do |handler|
          bucket_options.each do |option|
            handler.option(option[:name]) { return option[:action].call }
          end
        end
      end
    end
  end

  def bucket_options
    items = @s3_navigator.list_items
    options = []

    unless @s3_navigator.is_at_root
      options << { name: "Go Back", action: -> { @s3_navigator.go_back; nil } }
    end

    items[:folders].each do |folder|
      options << { name: "📁 #{folder[:name]}", action: -> { @s3_navigator.enter_folder(folder[:name]); nil } }
    end

    items[:files].each do |file|
      options << { name: "📄 #{file[:name]}", action: -> { @s3_navigator.download_file(file); nil } }
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
