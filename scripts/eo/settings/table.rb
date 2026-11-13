# frozen_string_literal: true

# EO::Settings: a script's settings table (Registry) and its listing (Listing).

module EO
  module Settings
    # The settings printed as `;<script> settings` shows them, one category
    # at a time. Included into a Setup that extends Registry and holds
    # @settings.
    module Listing
      def list(cat_to_list: 'all')
        mono = $frontend == 'stormfront'
        categories = cat_to_list == 'all' ? listed_categories : [cat_to_list]
        categories.each do |name|
          _respond("<output class=\"mono\"/>\n") if mono
          _respond("#{monsterbold_start}= #{name.capitalize} =#{monsterbold_end}\n")
          self.class.categories[name.to_sym].each_key do |key|
            value = listed_value(key)
            if value.is_a?(Array)
              _respond("  #{key}:")
              value.sort_by(&:to_s).each_with_index { |entry, i| _respond("    #{i + 1}. #{entry}") }
            else
              _respond("  #{key}: #{value}")
            end
          end
        end
        list_extra
        _respond("<output class=\"\"/>\n") if mono
      end

      # The categories `all` lists.
      def listed_categories = self.class.categories.keys.map(&:to_s)

      # How a setting reads in the listing.
      def listed_value(key) = @settings[key]

      # Anything printed after the categories.
      def list_extra = nil
    end

    # Extended into a script's Setup class, over its @@categories table:
    # { category => { key => { default: value, ... } } }.
    module Registry
      # @return [Hash{Symbol => Hash}] the class's @@categories
      def categories = class_variable_get(:@@categories)

      # @param key [Symbol]
      # @return [Symbol, nil] the category holding +key+
      def get_category(key)
        categories.each { |category, data| return category unless data[key].nil? }
        nil
      end

      # @param key [Symbol]
      # @return [Hash, nil] the setting's entry, its :default and the rest
      def get_setting(key)
        category = get_category(key)
        category && categories[category][key]
      end

      # Give every missing setting its default. Defaults are copied, so an
      # Array default is never shared between profiles.
      #
      # @param settings [Hash]
      # @param blank [Boolean] also replace an empty String or Array (ebounty's rule)
      # @return [Hash] +settings+
      def fill_defaults(settings, blank: false)
        categories.each_value do |data|
          data.each do |key, value|
            missing = blank ? settings[key].to_s.empty? : settings[key].nil?
            settings[key] = value[:default].dup if missing
          end
        end
        settings
      end

      # Drop the settings no category knows any more.
      #
      # @param settings [Hash]
      # @return [Hash] +settings+
      def prune(settings)
        settings.delete_if { |key, _| get_category(key).nil? }
      end
    end
  end
end
