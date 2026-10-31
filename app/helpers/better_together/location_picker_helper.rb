# frozen_string_literal: true

module BetterTogether
  # View helpers for the shared location picker partial (better_together/locations/_picker).
  module LocationPickerHelper
    LOCALE_SCOPE = 'better_together.locations.picker'
    Q_PLACEHOLDER = '%{q}' # rubocop:disable Style/FormatStringToken

    # Placeable class key (settlement) => full class name, from the same allow-list the lookup endpoint uses.
    def location_picker_type_map
      Geography::Placeable.included_in_models.to_h { |klass| [klass.name.demodulize.underscore, klass.name] }
    end

    # Options for the slim-select controller: remote search plus the "use typed name" and "new address" rows.
    # The %{q} placeholder is filled in by the JS controller, so it is passed through verbatim.
    def location_picker_slim_select_options
      model = Address.model_name.human
      {
        ajax: { url: available_locations_path(locale: I18n.locale) },
        createOptions: {
          simple: { label: t("#{LOCALE_SCOPE}.use_typed_name", q: Q_PLACEHOLDER) },
          types: [{ type: 'address', label: t("#{LOCALE_SCOPE}.create_new", model:),
                    labelWithQuery: t("#{LOCALE_SCOPE}.new_named_with_query", model:, q: Q_PLACEHOLDER) }]
        }
      }
    end

    # The select's single initial option for a record that already has a location.
    def location_picker_initial_option(record, type_map)
      location = record.location
      return [] unless location

      key = type_map.each_key.find { |candidate| location.location_type_matches?(candidate) }
      key ? [location_picker_place_option(location.location, type_map[key])] : location_picker_typed_option(location)
    end

    def location_picker_errors(record)
      record.errors[:location].presence || record.errors[:'location.location'].presence ||
        record.location&.errors&.full_messages.presence || []
    end

    private

    def location_picker_place_option(place, class_name)
      text = place.respond_to?(:to_formatted_s) ? place.to_formatted_s : place.to_s
      ["#{text} (#{place.class.model_name.human})", "#{class_name}:#{place.id}"]
    end

    def location_picker_typed_option(location)
      location.simple_location? && location.name.present? ? [[location.name, location.name]] : []
    end
  end
end
