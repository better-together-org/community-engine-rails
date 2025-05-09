# frozen_string_literal: true

module BetterTogether
  module Infrastructure
    # Represents a building in the real world
    class Building < Structure
      include Contactable
      include Creatable
      include Identifier
      include FriendlySlug
      include Geography::Geospatial::One
      include Privacy
      include PrimaryCommunity

      belongs_to :address,
                 -> { where(label: 'physical', physical: true, primary_flag: true) },
                 dependent: :destroy

      has_many :floors,
               -> { order(:level) },
               class_name: 'BetterTogether::Infrastructure::Floor',
               dependent: :destroy

      has_many :rooms,
               through: :floors,
               class_name: 'BetterTogether::Infrastructure::Room',
               dependent: :destroy

      accepts_nested_attributes_for :address, allow_destroy: true, reject_if: :blank?

      delegate :geocoding_string, to: :address, allow_nil: true

      geocoded_by :geocoding_string

      after_create :ensure_floor

      after_create :schedule_address_geocoding
      after_update :schedule_address_geocoding

      translates :name
      translates :description, backend: :action_text

      slugged :name

      def self.permitted_attributes(id: false, destroy: false)
        [
          {
            address_attributes: Address.permitted_attributes(id: true)
          }
        ] + super
      end

      def ensure_floor
        return if floors.size.positive?

        floors.create(name: 'Ground')
      end

      def schedule_address_geocoding
        return unless should_geocode?

        BetterTogether::Geography::GeocodingJob.perform_later(self)
      end

      def should_geocode?
        return false if geocoding_string.blank?

        # space.reload # in case it has been geocoded since last load

        (address_changed? or !geocoded?)
      end

      def select_option_title
        "#{name} (#{slug})"
      end

      def to_s
        name
      end
    end
  end
end
