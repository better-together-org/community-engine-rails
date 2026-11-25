# frozen_string_literal: true

module BetterTogether
  # View helpers for the address form's country / state / settlement selects (addresses/_geography_fields).
  module AddressGeographyHelper
    LOCALE_SCOPE = 'better_together.addresses.geography'
    Q_PLACEHOLDER = '%{q}' # rubocop:disable Style/FormatStringToken
    LEVELS = %i[country state settlement].freeze

    # Id of the select for a level, scoped by the form's object name so several forms can share a page.
    def address_geography_select_id(form, level)
      "#{form.object_name.to_s.gsub(/[^a-z0-9]+/i, '_').delete_suffix('_')}_#{level}_select"
    end

    # slim-select options: remote search narrowed by the level above, plus the "use my typed text" row.
    def address_geography_slim_select_options(form, level)
      parent = LEVELS[LEVELS.index(level) - 1] unless level == :country
      depends_on = {}
      depends_on[:country_id] = address_geography_select_id(form, :country) if parent
      depends_on[:state_id] = address_geography_select_id(form, :state) if level == :settlement
      # The parent select holds the id only when a record was picked; typed text must not narrow.
      {
        ajax: { url: geography_locations_path(locale: I18n.locale, level:), dependsOn: depends_on }.compact_blank,
        createOptions: { simple: { label: t("#{LOCALE_SCOPE}.use_typed_text", q: Q_PLACEHOLDER) } }
      }
    end

    # The single initial option: the linked record, else the typed text, else none.
    def address_geography_initial_option(address, level)
      record = address.association(level).reader
      return [[record.name, record.id]] if record

      typed = address.public_send(address_geography_string_column(level))
      typed.present? ? [[typed, typed]] : []
    end

    def address_geography_string_column(level)
      { country: :country_name, state: :state_province_name, settlement: :city_name }.fetch(level)
    end
  end
end
