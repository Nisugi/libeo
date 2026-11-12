# frozen_string_literal: true

module EO
  # A setting that names a script to run, with its arguments: "name arg arg",
  # several of them separated by commas.
  #
  # @param entry [String] one "name arg arg" entry
  # @return [Array(String, String)] the name and the arguments (nil when none)
  def self.split_script(entry)
    name, *args = entry.to_s.strip.split(/\s+/)
    [name, args.empty? ? nil : args.join(' ')]
  end

  # Run each script a setting lists, one after another, each to its end.
  #
  #   EO.run_scripts('eherbs, bigshot single')
  #
  # @param list [String] entries separated by commas
  # @return [void]
  def self.run_scripts(list)
    list.to_s.split(/,\s*/).each do |entry|
      name, args = split_script(entry)
      next if name.nil?
      args ? Script.run(name, args) : Script.run(name)
    end
  end
end
