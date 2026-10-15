# frozen_string_literal: true

require 'action_dispatch/routing/mapper'

module BetterTogether
  # Allows jsonapi-resources 0.10.x to keep passing a positional options hash to
  # Rails 8.1's keyword-based mapper resource initializer.
  module Rails81JSONAPIResourcesCompat
    # Adapts the mapper resource initializer to accept the legacy positional
    # options hash used by jsonapi-resources 0.10.x.
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

    # jsonapi-resources 0.10.x calls `resources name, options_hash`; Rails 8.1
    # deprecates the positional hash. Remove once the gem passes keywords.
    module MapperResourcesKeywordCompat
      def resources(*names, **options, &)
        options = names.pop.to_h.symbolize_keys.merge(options) if names.last.is_a?(Hash)

        super
      end
    end

    def self.apply!
      resource_class = ActionDispatch::Routing::Mapper::Resources::Resource
      resource_class.prepend(MapperResourceInitializeCompat) unless resource_class.ancestors.include?(MapperResourceInitializeCompat)

      mapper = ActionDispatch::Routing::Mapper::Resources
      mapper.prepend(MapperResourcesKeywordCompat) unless mapper.ancestors.include?(MapperResourcesKeywordCompat)
    end
  end

  Rails81JsonapiResourcesCompat = Rails81JSONAPIResourcesCompat
end

BetterTogether::Rails81JSONAPIResourcesCompat.apply! if Rails.gem_version >= Gem::Version.new('8.1.0')
