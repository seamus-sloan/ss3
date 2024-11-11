require 'aws-sdk-s3'
require 'cli/ui'

class S3Navigator
  def initialize(bucket_name)
    @bucket_name = bucket_name
    @s3_client = Aws::S3::Client.new
    @current_path = [""]
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
      display_options = options
      CLI::UI::Frame.open("") do
        CLI::UI::Prompt.ask("Select an option: ") do |handler|
          display_options.each do |display_option|
            handler.option(display_option[:name]) { display_option[:action].call }
          end
        end
      end
    end
  end

  def options
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

    # Display options for current directory
    def display_options
      items = @s3_navigator.list_objects
      options = []

      # Only add 'Go Back' if not at the root
      options << { name: 'Go Back', action: -> { @s3_navigator.go_back } } unless @s3_navigator.at_root?

      # Add folders and files as options
      items[:folders].each do |folder|
        options << { name: "📁 #{folder}", action: -> { @s3_navigator.enter_folder(folder) } }
      end

      items[:files].each do |file|
        options << { name: "📄 #{file}", action: -> { file_options(file) } }
      end

      # Ensure there's always something to display
      options = [{ name: 'No items available', action: -> {} }] if options.empty?
      options
    end
end

s3_navigator = S3Navigator.new("aerodome-drone-controller-logs")
ui_navigator = UINavigator.new(s3_navigator)
ui_navigator.start
