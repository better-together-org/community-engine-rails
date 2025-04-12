# frozen_string_literal: true

module BetterTogether
  class Address < ApplicationRecord # rubocop:todo Style/Documentation
    include PrimaryFlag
    include Privacy

    primary_flag_scope :contact_detail_id, allow_blank: true

    LABELS = %i[main mailing physical home work billing shipping other].freeze
    include Labelable

    belongs_to :contact_detail,
               class_name: 'BetterTogether::ContactDetail',
               optional: true

    # Validations
    validates :physical, :postal, inclusion: { in: [true, false] }
    validate :at_least_one_address_type

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
        postal_code country_name
      ]
    end

    def to_formatted_s(
      included: %i[line1 line2 city_name state_province_name postal_code country_name],
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

    protected

    def at_least_one_address_type
      return if physical || postal

      errors.add(:base, 'Address must be either physical, postal, or both')
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
