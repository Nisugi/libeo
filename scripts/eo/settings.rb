# frozen_string_literal: true

module EO
  # The settings window every e-script carries: whether Lich can open one,
  # the category table its settings live in, and the small helpers ebounty's
  # and eloot's ListSettingsForm windows share.
  module Settings
    # @param form [Symbol] the Lich::WebUI form class the window is built on
    # @return [Boolean] whether Lich can open a WebUI window with that form
    def self.available?(form = :SettingsForm)
      defined?(Lich::WebUI) && Lich::WebUI.respond_to?(:presentation_enabled?) && Lich::WebUI.presentation_enabled? &&
        Lich::WebUI.const_defined?(form, false) ? true : false
    end

    # ListSettingsForm keys rows by position and seeds each viewer's table
    # selection only once, so after Add or Delete the window would keep
    # highlighting a row the form no longer has selected (and Delete would do
    # nothing). Clearing that viewer's selection keeps the two in step.
    #
    # @return [Class] a Lich::WebUI::ListSettingsForm subclass, one per loaded WebUI
    def self.list_form
      base = Lich::WebUI::ListSettingsForm
      (@list_forms ||= {})[base] ||= Class.new(base) do
        private

        def render_field(tree, field, refs, **overrides)
          ref = super
          (@tables ||= {})[field[:key]] = ref if field && @lists.key?(field[:key])
          ref
        end

        def change_list(key, action, event)
          super
          table = @tables&.[](key)
          @page.set(table.cid, :selected, [], viewer: event.viewer_id) if table
        end
      end
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

    # Included into a ListSettingsForm Setup (ebounty, eloot). Expects
    # @settings, @form and a SPINS table of key => [max, step, digits].
    module Controls
      def boolean?(key)
        [true, false].include?(self.class.get_setting(key)[:default])
      end

      # The saved number as the spin box shows it: clamped and on a step.
      def spin_value(key)
        max, step, digits = self.class::SPINS.fetch(key)
        number = digits.zero? ? @settings[key].to_i : @settings[key].to_f
        ((number.clamp(0, max) / step).round * step).round(digits)
      end

      # The number to save from the spin box. An untouched box keeps the
      # saved value even when that was off its step.
      def number_setting(key, value)
        raise ArgumentError, "#{key} must be a number." unless value.is_a?(Numeric)
        return @settings[key] if value == spin_value(key)

        max, _step, digits = self.class::SPINS.fetch(key)
        (digits.zero? ? value.round : value.to_f.round(digits)).clamp(0, max)
      end

      def cancel
        @form.close
      end

      def place(slot)
        slot ? { slot: slot } : {}
      end

      def tip_for(tip)
        tip ? { tooltip: tip } : {}
      end

      def hint_for(hint)
        hint ? { placeholder: hint } : {}
      end
    end
  end
end
