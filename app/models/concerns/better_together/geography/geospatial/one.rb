# frozen_string_literal: true

module BetterTogether
  module Geography
    module Geospatial
      module One # rubocop:todo Style/Documentation
        extend ActiveSupport::Concern

        included do
          has_one :geospatial_space, class_name: 'BetterTogether::Geography::GeospatialSpace', as: :geospatial,
                                     dependent: :destroy
          has_one :space, through: :geospatial_space

          accepts_nested_attributes_for :space

          after_create :ensure_space_presence
          after_update :ensure_space_presence
        end

        def ensure_space_presence
          return if space.present?

          create_geospatial_space
        end
      end
    end
  end
end
