# frozen_string_literal: true

module BetterTogether
  module Geography
    module Mappable # rubocop:todo Style/Documentation
      extend ActiveSupport::Concern

      included do
        has_one :map,
                class_name: 'BetterTogether::Geography::Map',
                as: :mappable,
                dependent: :destroy

        after_create :create_map, if: ->(obj) { obj.map.nil? }
        after_update :create_map, if: ->(obj) { obj.map.nil? }
      end
    end
  end
end
