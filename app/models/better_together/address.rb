# frozen_string_literal: true

module BetterTogether
  class Address < PlatformRecord # rubocop:todo Style/Documentation
    include Geography::Geospatial::One

    geocodes_self
    include Geography::Locatable::Many
    include Geography::Placeable
    include PrimaryFlag
    include Privacy

    primary_flag_scope :contact_detail_id, allow_blank: true

    LABELS = %i[main mailing physical home work billing shipping other].freeze
    include Labelable

    belongs_to :contact_detail,
               class_name: 'BetterTogether::ContactDetail',
               optional: true
    has_many :buildings, class_name: 'BetterTogether::Infrastructure::Building'

    # Validations
    validates :physical, :postal, inclusion: { in: [true, false] }
    validate :at_least_one_address_type

    after_update :update_buildings

    def self.address_formats
      {
        short: {
          included: %i[line1 city_name state_province_name]
        }
      }
    end

    def self.permitted_attributes(id: false, destroy: false)
      super + %i[
        physical postal line1 line2 city_name state_province_name
        postal_code country_name primary_flag
      ]
    end

    # Placeable: reuse an existing Address when the picker selected one (matching
    # Placeable's own default lookup), otherwise build a new Address from nested
    # locatable_location attrs (unlike Settlement/Region, which rely on Placeable's
    # lookup-only default for every case).
    #
    # attrs may carry keys that only make sense on LocatableLocation itself (name,
    # location_id, location_type, ...) — slice down to Address's own permitted
    # attributes instead of blacklisting individual foreign keys, so passing an
    # unrelated key here raises a clear "not permitted" error at the controller
    # layer rather than an ActiveModel::UnknownAttributeError from .new.
    def self.locatable_location_build(attrs)
      existing = find_by(id: attrs['id'] || attrs['location_id'])
      return existing if existing

      allowed_keys = permitted_attributes(id: true).grep(Symbol).map(&:to_s)
      new(attrs.slice(*allowed_keys))
    end

    def self.inline_create_fields_partial
      'better_together/addresses/address_fields'
    end

    def geocoding_string
      to_formatted_s(excluded: %i[display_label line2])
    end

    def to_formatted_s(
      included: %i[display_label line1 line2 city_name state_province_name postal_code country_name],
      excluded: [],
      format: nil
    )
      included, excluded = resolve_format(format, included, excluded)

      attrs = included - excluded
      attrs.map { |attr| public_send(attr) }
           .select(&:present?).join(', ')
    end

    def to_s
      to_formatted_s
    end

    # This is called on save to ensure that all associated buildings are saved and geocoded as needed
    def update_buildings
      return unless previous_changes.any?

      buildings.each(&:save)
    end

    def select_option_title
      # Combine display label (e.g., 'Main') with the formatted address for clarity
      parts = []
      parts << display_label if respond_to?(:display_label) && display_label.present?

      formatted = to_formatted_s(excluded: %i[display_label line2])
      parts << formatted if formatted.present?

      parts.join(' — ')
    end

    protected

    def at_least_one_address_type
      return if physical || postal

      errors.add(:base, I18n.t('errors.models.address_missing_type'))
    end

    def resolve_format(format, included, excluded)
      return [included, excluded] unless self.class.address_formats[format]

      address_format = self.class.address_formats[format]
      format_included = address_format[:included]
      format_excluded = address_format[:excluded]

      included = format_included if format_included.present?
      excluded = format_excluded if format_excluded.present?

      [included, excluded]
    end
  end
end
