# frozen_string_literal: true

# EO::Settings: the setup window's shared parts: the ListSettingsForm
# fix, the plain window's footer, the controls and ListForm.

module EO
  module Settings
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

    # The footer of a plain SettingsForm window (eherbs, ecleanse, ewaggle):
    # what closing does, Cancel, and Save & Close. Call it as
    # EO::Settings.footer from inside a layout block.
    #
    # @param status [String] a message to show ahead of the note
    # @param tooltip [String, nil] Save & Close's tooltip
    # @param wrap [Boolean] let the note wrap
    def self.footer(ui, save, cancel, status: '', tooltip: nil, wrap: false)
      ui.columns(key: 'footer', count: 3, weights: [5, 1, 1], compact: true, row_align: :center, gap: 6) do
        ui.text(slot: '0', key: 'footer-text', **(wrap ? { wrap: true } : {}), emphasis: :subtle,
                content: "#{status.to_s.empty? ? '' : "#{status}    "}Cancel or closing the window discards changes.")
        ui.button(slot: '1', key: 'cancel', label: 'Cancel', on: { activate: ->(_ev) { cancel.call } })
        save.call(ui, slot: '2', variant: :primary, **(tooltip ? { tooltip: tooltip } : {}))
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

      # Disabled only when true; Lich reads a missing key as enabled.
      def off_for(off)
        off ? { disabled: true } : {}
      end
    end

    # The settings window ebounty and eloot build on Lich's ListSettingsForm:
    # the settings turned into window values and back, the Add/Delete lists,
    # and the controls the tabs are drawn with. Lich's form owns the window,
    # Save and Cancel, validation and the field widgets; this is the part it
    # leaves to the caller.
    #
    # The including Setup defines PAGE_ID, SPINS, MEMBERS (array settings
    # shown as one checkbox per value, as [[value, label], ...]), LISTS (array
    # settings shown as Add/Delete tables), SELECTS (key => [[value, label],
    # ...]) and EXCLUSIVE (key => group), and the methods shown_keys, title,
    # apply(result), notify(text) and layout(ui, field, save). The methods
    # under "hooks" are there to be overridden.
    module ListForm
      include Controls

      attr_reader :drafts, :live, :status

      # Opens the window and waits. Save & Close returns the edited
      # settings, which apply saves; Cancel or closing the window discards them.
      def start
        result = form.show.wait
        if result
          apply(result)
          notify(' Setup saved.')
        else
          notify(' Setup closed without saving.')
        end
      end

      # The window, ready to show. Lists are edited on copies so Cancel
      # discards them too.
      def form
        setup = self
        @live = form_values
        @drafts = self.class::LISTS.to_h { |key| [key, Array(@settings[key]).dup] }
        @refs = {}
        @status = ''
        @form = Settings.list_form.new(owner: @owner, id: self.class::PAGE_ID, title: title, values: @live, fields: fields,
                                       lists: self.class::LISTS.to_h { |key| [key, list_spec(key)] },
                                       normalize: ->(draft) { setup.normalize(draft) },
                                       layout: ->(ui, field, save) { setup.layout(ui, field, save) },
                                       props: { size: [900, 820], viewport: true })
      end

      def member_key(key, value)
        :"#{key}-#{value.to_s.tr(' ', '_')}"
      end

      def fields
        consts = self.class
        list = shown_keys.reject { |key| consts::LISTS.include?(key) || consts::MEMBERS.key?(key) }.map do |key|
          if (field = field_for(key))
            field
          elsif consts::SPINS.key?(key)
            max, step, digits = consts::SPINS[key]
            { key: key, type: :number_input, min: 0, max: max, step: step, digits: digits, stepper_buttons: true, align: :start }
          elsif consts::SELECTS.key?(key)
            { key: key, type: :select, options: consts::SELECTS[key].map { |value, text| { value: value, label: text } } }
          elsif boolean?(key)
            { key: key, type: :checkbox, exclusive: exclusive_for(key) }.compact
          else
            { key: key, type: :text_input }
          end
        end
        consts::MEMBERS.each { |key, items| items.each { |value, _| list << { key: member_key(key, value), type: :checkbox } } }
        list
      end

      def form_values
        consts = self.class
        shown_keys.each_with_object({}) do |key, values|
          if consts::MEMBERS.key?(key)
            consts::MEMBERS[key].each { |value, _| values[member_key(key, value)] = Array(@settings[key]).include?(value) }
          elsif consts::LISTS.include?(key)
            values[key] = Array(@settings[key]).dup
          elsif consts::SPINS.key?(key)
            values[key] = spin_value(key)
          elsif consts::SELECTS.key?(key)
            values[key] = select_value(key)
          elsif boolean?(key)
            values[key] = @settings[key] ? true : false
          else
            values[key] = text_value(key)
          end
        end
      end

      # A saved value that is not one of the choices shows the first choice.
      def select_value(key)
        value = @settings[key].to_s
        choices = self.class::SELECTS.fetch(key)
        choices.any? { |option, _| option == value } ? value : choices.first.first
      end

      # The submitted window values back into settings. A number or choice
      # left as displayed keeps its saved value, even one the window had to
      # adjust.
      def normalize(draft)
        consts = self.class
        result = shown_keys.to_h do |key|
          value =
            if consts::MEMBERS.key?(key)
              known = consts::MEMBERS[key].map(&:first)
              (Array(@settings[key]) - known + known.select { |item| draft[member_key(key, item)] }).uniq.sort
            elsif consts::LISTS.include?(key)
              Array(draft[key]).dup
            elsif consts::SPINS.key?(key)
              number_setting(key, draft[key])
            elsif consts::SELECTS.key?(key)
              draft[key] == select_value(key) ? @settings[key] : draft[key].to_s
            elsif boolean?(key)
              draft[key] ? true : false
            else
              draft[key].to_s.strip
            end
          [key, value]
        end
        finish(result)
      end

      # --- the Add/Delete lists ---------------------------------------------

      def list_spec(key)
        setup = self
        { columns: list_columns(key), rows: proc { setup.list_rows(key) }, value: proc { setup.drafts[key].dup },
          add: ->(text) { setup.add_entry(key, text) }, delete: ->(index) { setup.delete_entry(key, index) },
          clear_after_add: true }
      end

      def list_rows(key)
        @drafts[key].map { |entry| { 'entry' => entry.to_s } }
      end

      def add_entry(key, text)
        text = text.to_s.strip
        return if text.empty?
        return unless accept_entry?(key, text)

        list = @drafts[key]
        list.push(text) unless list.map(&:to_s).include?(text)
        sort_list(key, list)
        @status = ''
      end

      def delete_entry(key, index)
        @drafts[key].delete_at(index)
        sort_list(key, @drafts[key])
      end

      # --- controls -----------------------------------------------------------

      def control(ui, key, **props)
        @refs[key] = @field.call(ui, key, **props)
      end

      def render_check(ui, key, label, slot: nil, off: false, tip: nil, on: nil)
        events = on ? { on: on } : check_events(key)
        control(ui, key, label: label, disabled: off || unavailable?(key), **place(slot), **tip_for(tip), **events)
      end

      # Checkboxes over one array setting. items: [stored value, label]
      def render_members(ui, key, items, off: false, tips: {}, columns: 4)
        setup = self
        items.each_slice(columns).with_index do |group, row|
          ui.columns(key: "#{key}-#{row}", count: columns, gap: 8) do
            group.each_with_index do |(value, label), column|
              setup.control(ui, setup.member_key(key, value), slot: column.to_s, label: label, **setup.off_for(off), **setup.tip_for(tips[value]))
            end
          end
        end
      end

      def render_entry(ui, key, label = nil, slot: nil, off: false, tip: nil, hint: nil)
        control(ui, key, **(label ? { label: label } : {}), disabled: off, **place(slot), **tip_for(tip), **hint_for(hint))
      end

      # A text box with its label beside it instead of above it.
      def render_inline_entry(ui, key, label, off: false, tip: nil, hint: nil)
        setup = self
        ui.columns(key: "#{key}-row", count: 2, weights: inline_weights, gap: 8, compact: true, row_align: :center) do
          ui.text(slot: '0', key: "#{key}-label", content: label, **setup.tip_for(tip))
          setup.render_entry(ui, key, slot: '1', off: off, tip: tip, hint: hint)
        end
      end

      def render_spin(ui, key, label, slot: nil, off: false, tip: nil)
        control(ui, key, label: label, **off_for(off), **place(slot), **tip_for(tip))
      end

      def render_select(ui, key, label, slot: nil, off: false, tip: nil)
        control(ui, key, label: label, **off_for(off), **place(slot), **tip_for(tip))
      end

      # An Add/Delete list: entry box, Add and Delete in a row, above the
      # table. The entry comes first because Add submits it.
      def render_list(ui, key, title, slot: nil, off: false, tip: nil, hint: nil, height: 220)
        setup = self
        ui.group(key: "#{key}-box", label: title, **place(slot), **tip_for(tip)) do
          ui.columns(key: "#{key}-controls", count: 3, weights: [3, 1, 1], gap: 4, compact: true, row_align: :center) do
            setup.control(ui, :"#{key}_entry", slot: '0', **setup.off_for(off), **setup.hint_for(hint))
            setup.control(ui, :"#{key}_add", slot: '1', label: 'Add', **setup.off_for(off))
            setup.control(ui, :"#{key}_delete", slot: '2', label: 'Delete', **setup.off_for(off))
          end
          setup.control(ui, key, headers: setup.list_headers?(key), min_height: height, max_height: height, **setup.off_for(off))
        end
      end

      def render_footer(ui, save)
        setup = self
        script = self.class::PAGE_ID.sub(/-setup\z/, '')
        note = "#{@status.to_s.empty? ? '' : "#{@status}    "}Save & Close saves your settings. Cancel or closing the window discards your changes."
        ui.divider(key: 'footer-div')
        ui.columns(key: 'footer', count: 3, weights: [5, 1, 1], compact: true, row_align: :center, margin: 6) do
          ui.text(slot: '0', key: 'footer-text', wrap: true, content: note)
          ui.button(slot: '1', key: 'cancel', label: 'Cancel', tooltip: 'Close this window without saving.', on: { activate: ->(_ev) { setup.cancel } })
          save.call(ui, slot: '2', variant: :primary, tooltip: "Save the settings to your #{script} profile and close this window.")
        end
      end

      # --- hooks ---------------------------------------------------------------

      # A field definition of the script's own for +key+, or nil for the usual one.
      def field_for(_key) = nil

      def exclusive_for(key) = self.class::EXCLUSIVE[key]

      # A text box's value as shown.
      def text_value(key) = @settings[key].to_s

      # The settings as normalize built them, for rules across fields.
      def finish(result) = result

      def list_columns(_key) = [{ key: 'entry', label: 'Entry', expand: true }]

      def list_headers?(_key) = false

      # false refuses an entry; set @status to say why.
      def accept_entry?(_key, _text) = true

      def sort_list(_key, list)
        list.uniq!
        list.sort_by!(&:to_s)
      end

      # An option this character cannot use, shown disabled.
      def unavailable?(_key) = false

      # A checkbox's events when the caller gives none.
      def check_events(_key) = {}

      def inline_weights = [1, 2]
    end
  end
end
