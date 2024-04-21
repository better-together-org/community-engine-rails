# frozen_string_literal: true

module BetterTogether
  # Concern that when included helps the model work with resource_types
  module Resourceful
    extend ActiveSupport::Concern

    RESOURCE_CLASSES = [
      'BetterTogether::Community',
      'BetterTogether::Platform'
    ].freeze

    included do
      validates :resource_type, inclusion: { in: RESOURCE_CLASSES }

      # Retrieves all roles associated with a given class type
      def self.for_class(klass)
        where(resource_type: klass.name)
      end
    end
      
  end
end
