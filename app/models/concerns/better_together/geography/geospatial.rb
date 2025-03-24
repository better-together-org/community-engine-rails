# frozen_string_literal: true

module BetterTogether
  module Geography
    module Geospatial # rubocop:todo Style/Documentation
      extend ActiveSupport::Concern

      included do
        has_one :space, class_name: 'BetterTogether::Geography::Space', as: :geospatial, dependent: :destroy
      end
    end
  end
end
