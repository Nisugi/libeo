# frozen_string_literal: true

require 'terminal-table'

module EO
  # A Terminal::Table help block in the layout every e-script uses.
  #
  #   EO.help([['setup', 'UI configuration tool'], ['load', 'Reloads all settings']])
  #
  # Each row is [command, description]; the command is prefixed with ;scriptname.
  # A row that is a String becomes a centered full-width line; :separator passes through.
  #
  # @param rows [Array<Array(String, String), String, Symbol>]
  # @param title [String, nil]
  # @return [void]
  def self.help(rows, title: nil)
    name = Script.current&.name.to_s
    table_rows = rows.map do |row|
      case row
      when Symbol then row
      when String then [{ value: row, colspan: 2, alignment: :center }]
      else
        cmd, desc = row
        cmd = cmd.to_s.empty? ? "#{$lich_char}#{name}" : "#{$lich_char}#{name} #{cmd}"
        [cmd, desc.to_s]
      end
    end
    title ||= "#{name.capitalize} ver #{Script.version(name)}"
    table = Terminal::Table.new(title: title, rows: table_rows)
    respond
    respond table
    respond
  end
end
