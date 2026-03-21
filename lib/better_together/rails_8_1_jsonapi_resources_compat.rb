# frozen_string_literal: true

require 'action_dispatch/routing/mapper'

module BetterTogether
  # Allows jsonapi-resources 0.10.x to keep passing a positional options hash to
  # Rails 8.1's keyword-based mapper resource initializer.
  module Rails81JsonapiResourcesCompat
    module MapperResourceInitializeCompat
      def initialize(entities, api_only, shallow, legacy_options = nil, **options)
        merged_options =
          if legacy_options.is_a?(Hash)
            legacy_options.merge(options)
          else
            options
          end

        super(entities, api_only, shallow, **merged_options)
      end
    end

    def self.apply!
      resource_class = ActionDispatch::Routing::Mapper::Resources::Resource
      return if resource_class.ancestors.include?(MapperResourceInitializeCompat)

      resource_class.prepend(MapperResourceInitializeCompat)
    end
  end
end

BetterTogether::Rails81JsonapiResourcesCompat.apply! if Rails.gem_version >= Gem::Version.new('8.1.0')
