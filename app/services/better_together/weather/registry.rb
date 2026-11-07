# frozen_string_literal: true

module BetterTogether
  module Weather
    # Allow-list of weather adapters. Hosts register extra adapters (other countries
    # or sources) from an initializer: Registry.register('met_office', 'MyApp::MetOffice').
    module Registry
      BUILT_IN = {
        'environment_canada' => 'BetterTogether::Weather::Adapters::EnvironmentCanada'
      }.freeze

      class UnknownAdapter < StandardError; end

      class << self
        def register(key, class_name)
          extra[key.to_s] = class_name.to_s
        end

        def keys
          adapters.keys
        end

        def registered?(key)
          adapters.key?(key.to_s)
        end

        def build(key, config = {})
          class_name = adapters.fetch(key.to_s) { raise UnknownAdapter, "Unknown weather adapter: #{key}" }
          class_name.constantize.new(config)
        end

        def reset!
          extra.clear
        end

        private

        def adapters
          BUILT_IN.merge(extra)
        end

        def extra
          @extra ||= {}
        end
      end
    end
  end
end
