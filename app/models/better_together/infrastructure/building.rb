# frozen_string_literal: true

module BetterTogether
  module Infrastructure
    class Building < Structure
      include Contactable
      include Creatable
      include Identifier
      include FriendlySlug
      include Geography::Geospatial::One
      include Privacy
      include PrimaryCommunity
      include Searchable

      after_create :ensure_floor

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

      translates :name
      translates :description, backend: :action_text

      slugged :name

      settings index: { number_of_shards: 1 } do
        mappings dynamic: 'false' do
          indexes :name, as: 'name'
          indexes :description, as: 'description'
          indexes :rich_text_content, type: 'nested' do
            indexes :body, type: 'text'
          end
          indexes :rich_text_translations, type: 'nested' do
            indexes :body, type: 'text'
          end
        end
      end

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

      # def address_attributes=(attrs = {})
      #   if address
      #     address.update(attrs.except(:type))
      #   else
      #     build_address(attrs.except(:type))
      #   end
      # end

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
