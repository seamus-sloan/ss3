#!/usr/bin/env ruby

class UiHelper
  def initialize(window, page_size)
    @window = window
    @page_size = page_size
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
  def display_info(message)
    @window.setpos(Curses.lines - 5, 0)
    @window.addstr(message.ljust(Curses.cols))
    @window.addstr("Press any key to continue.")
    @window.refresh
    @window.getch
  end

  # Clears the specified line(s).
  def clear_lines(lines)
    Array(lines).each do |line|
      @window.setpos(line, 0)
      @window.addstr(" " * Curses.cols)
    end
    @window.refresh
  end

  # Clears the error message (5), continue text (4), and input lines (3).
  def clear_info
    clear_lines(Curses.lines - 5 .. Curses.lines - 3)
  end

  # Display the initial prompt for selecting a bucket
  def display_bucket_prompt
    @window.clear
    @window.setpos(Curses.lines - 4, 0)
    @window.addstr("Please enter a bucket name to proceed.")
    @window.setpos(Curses.lines - 1, 0)
    @window.attron(Curses::A_REVERSE) do
      @window.addstr("[P]: Adjust Profile [R]: Adjust Region [N]: Enter Bucket Name [Q]: Quit")
    end
    @window.refresh
  end

  # Display available profiles for user selection
  def display_profile_prompt(profiles)
    @window.clear
    @window.setpos(0, 0)
    @window.addstr("Available Profiles:\n\n")
    profiles.each_with_index do |profile, index|
      @window.addstr("[#{index}] #{profile}\n")
    end
    @window.addstr("\nSelect a profile by its number or press 'Q' to cancel.\n")

    # Add the bottom menu bar
    @window.setpos(Curses.lines - 1, 0)
    @window.attron(Curses::A_REVERSE) do
      @window.addstr("[Q] Cancel | [0-9] Select profile".ljust(Curses.cols))
    end
    @window.refresh
  end

  # Display available regions for user selection
  def display_region_prompt(regions)
    @window.clear
    @window.setpos(0, 0)
    @window.addstr("Available Regions:\n\n")
    regions.each_with_index do |region, index|
      @window.addstr("[#{index}] #{region}\n")
    end
    @window.addstr("\nSelect a region by its number or press 'q' to cancel.\n")

    # Add the bottom menu bar
    @window.setpos(Curses.lines - 1, 0)
    @window.attron(Curses::A_REVERSE) do
      @window.addstr("[Q] Cancel | [0-9] Select region".ljust(Curses.cols))
    end
    @window.refresh
  end

  # Render UI with pagination.
  def display_page(bucket, prefix, items, page)
    @window.clear
    start_index = page * @page_size
    end_index = [start_index + @page_size, items.size].min
    page_count = (items.size / @page_size.to_f).ceil

    # Display bucket path, contents, and pagination info
    @window.setpos(0, 0)
    @window.addstr("Current Bucket: #{bucket} /#{prefix} (Page #{page + 1} of #{page_count})\nContents:\n")

    # Display items with timestamps
    items[start_index...end_index].each_with_index do |item, index|
      timestamp = item[:last_modified] ? item[:last_modified].strftime("%Y-%m-%d %H:%M:%S") : ""
      @window.addstr("#{"[#{start_index + index}]".ljust(6)} #{timestamp.ljust(15)} #{item[:name].ljust(30)}\n")
    end

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

  # Display help information.
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
