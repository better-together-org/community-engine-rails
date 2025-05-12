# frozen_string_literal: true

# Join model between BetterTogether::Infrastructure::Building and associated record
module BetterTogether
  module Infrastructure
    # Connects a building to another data type (polymorphic)
    class BuildingConnection < ApplicationRecord
      include BetterTogether::Positioned
      include BetterTogether::PrimaryFlag

      primary_flag_scope(:connection_id)

      belongs_to :building,
                 class_name: 'BetterTogether::Infrastructure::Building'

      belongs_to :connection, polymorphic: true

      accepts_nested_attributes_for :building, reject_if: :all_blank

      before_validation :set_new_building_details, if: :new_record?

      delegate :address, :address?, :name_is_address?, :name, to: :building

      def self.permitted_attributes(id: false, destroy: false)
        [
          :connection_id,
          {
            building_attributes: ::BetterTogether::Infrastructure::Building.permitted_attributes(id: true)
          }
        ] + super
      end

      def building
        super || build_building
      end

      protected

      def set_new_building_details
        return unless connection

        return if building.name.present?

        building.name = if building.address_id
          building.address.geocoding_string
        elsif connection.respond_to?(:name)
          connection.name
        elsif connection.respond_to?(:title)
          connection.title
        else
          connection.to_s
        end
        building.description = connection.description
        building.privacy = connection.privacy
      end
    end
  end
end
