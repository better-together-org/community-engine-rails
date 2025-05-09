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
    end
  end
end
