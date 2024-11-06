#!/usr/bin/env ruby

class UI
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
  def display_error(message)
    @window.setpos(Curses.lines - 5, 0)
    @window.addstr(message.ljust(Curses.cols))
    @window.addstr("Press any key to continue.")
    @window.refresh
    @window.getch
  end

  # Clears the specified line(s)
  def clear_lines(lines)
    Array(lines).each do |line|
      @window.setpos(line, 0)
      @window.addstr(" " * Curses.cols) # Clear each line
    end
    @window.refresh
  end

  def clear_error_message
    clear_lines(Curses.lines - 5 .. Curses.lines - 3)
  end

  # Render UI with pagination
  def display_page(bucket, prefix, items, page)
    @window.clear
    start_index = page * @page_size
    end_index = [start_index + @page_size, items.size].min
    page_count = (items.size / @page_size.to_f).ceil

    # Display bucket path, contents, and pagination info
    @window.setpos(0, 0)
    @window.addstr("Current Bucket: #{bucket} /#{prefix} (Page #{page + 1} of #{page_count})\nContents:\n")
    items[start_index...end_index].each_with_index { |item, index| @window.addstr("[#{start_index + index}] #{item}\n") }

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

  # Display help information
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
