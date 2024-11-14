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

  def list_items
    prefix = @current_path.last
    # puts "Prefix: #{prefix}"
    response = @s3_client.list_objects_v2(bucket: @bucket_name, prefix: prefix, delimiter: '/')

    # puts "Contents: #{response}"

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
      CLI::UI::Frame.open("Main Menu") do
        puts @s3_navigator.current_profile
        puts @s3_navigator.current_region
        CLI::UI::Prompt.ask("SS3 Main Menu Option: ") do |handler|
          main_menu_options.each do |option|
            handler.option(option[:name]) { option[:action].call }
          end
        end
      end
    end
  end

  def main_menu_options
    options = []
    current_region = @s3_navigator.current_region.empty? ? "NOT SET" : @s3_navigator.current_region
    current_profile = @s3_navigator.current_profile.empty? ? "NOT SET" : @s3_navigator.current_profile

    options << {name: "Change AWS Region (Current: #{current_region})", action: -> {change_aws_region}}
    options << {name: "Change AWS Profile (Current: #{current_profile})", action: -> {change_aws_profile}}

    if @s3_navigator.bucket_name.nil?
      options << {name: "Enter Bucket Name", action: -> { enter_bucket_name }}
    else
      options << {name: "Change Bucket Name", action: -> { update_bucket_name(@s3_navigator.bucket_name) }}
      options << {name: "Enter '#{@s3_navigator.bucket_name}'", action: -> { bucket_navigation }}
    end

    options << {name: "Quit", action: -> { exit }}
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
      # display_options = bucket_options
      CLI::UI::Prompt.ask("Select an option: ") do |handler|
        # display_options.each do |option|
        bucket_options.each do |option|
          handler.option(option[:name]) { option[:action].call }
        end
      end
    end
  end

  def bucket_options
    items = @s3_navigator.list_items
    options = []

    if !@s3_navigator.is_at_root
      options << {name: "Go Back", action: -> {@s3_navigator.go_back}}
    end

    items[:folders].each do |folder|
      options << {name: folder[:name], action: -> {@s3_navigator.enter_folder(folder[:name])}}
    end

    items[:files].each do |file|
      options << {name: file[:name], action: -> {@s3_navigator.download_file(file)}}
    end

    options
  end
end









s3_navigator = S3Navigator.new(ARGV[0])
ui_navigator = UINavigator.new(s3_navigator)
ui_navigator.start
