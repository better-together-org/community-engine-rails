# frozen_string_literal: true

module BetterTogether
  # Concern that when included helps the model work with resource_types
  module Resourceful
    extend ActiveSupport::Concern

    RESOURCE_CLASSES = [
      'BetterTogether::Community',
      'BetterTogether::Platform',
      'BetterTogether::Person',
      'BetterTogether::Metrics',
      'BetterTogether::Metrics::Report'
    ].freeze

    @registered = {}

    class << self
      # Lets a host add a resource type (a Community subtype, see BetterTogether::CommunitySubtype) that roles and
      # permissions can be scoped to. label is a String or a callable that returns the name shown on the role tabs.
      def register_resource_class(name, label: nil)
        @registered[name.to_s] = label
      end

      def allowed_resource_classes
        RESOURCE_CLASSES + @registered.keys
      end

      def label_for(resource_type)
        label = @registered[resource_type.to_s]
        label.respond_to?(:call) ? label.call : label
      end
    end

    included do
      validates :resource_type, inclusion: { in: ->(_record) { BetterTogether::Resourceful.allowed_resource_classes } }

      # Retrieves all roles associated with a given class type
      def self.for_class(klass)
        where(resource_type: klass.name)
      end
    end
  end
end
