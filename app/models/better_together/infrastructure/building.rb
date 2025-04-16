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

      geocoded_by :address

      after_create :ensure_floor

      after_validation :geocode, if: ->(obj) { obj.address.present? and (obj.address_changed? || obj.geocoded?) }

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

      def address
        super || build_address(primary_flag: true)
      end

      def ensure_floor
        return if floors.size.positive?

        floors.create(name: 'Ground')
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
