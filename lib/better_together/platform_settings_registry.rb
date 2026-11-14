# frozen_string_literal: true

# Registry of per-platform settings declared by extension gems.
module BetterTogether
  # Lets extension gems declare per-platform settings. Registered settings are stored under
  # Platform#settings['integrations'][group][field] and rendered on the platform form's
  # Integrations tab. Only registered keys are ever stored.
  module PlatformSettingsRegistry
    TYPES = %i[string boolean text select].freeze
    KEY_FORMAT = /\A[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*\z/

    # One declared setting.
    Definition = Struct.new(:key, :type, :label, :hint, :default, :pattern, :validator, :secret,
                            :env_fallback, :options, :group_label, keyword_init: true) do
      def group = key.split('.', 2).first
      def field = key.split('.', 2).last

      # Returns an error message for an invalid value, or nil.
      def error_for(value)
        return if value.blank? && value != false

        builtin_error(value) || validator&.call(value)
      end

      def builtin_error(value)
        return 'is not one of the allowed options' if type == :select && options.map(&:to_s).exclude?(value.to_s)

        'has an invalid format' if pattern && !pattern.match?(value.to_s)
      end

      def cast(value)
        return ActiveModel::Type::Boolean.new.cast(value) || false if type == :boolean

        value.is_a?(String) ? value.strip.presence : value
      end
    end

    class << self
      def definitions
        @definitions ||= {}
      end

      # rubocop:disable-next Metrics/ParameterLists
      def register(key, type: :string, label: nil, hint: nil, default: nil, pattern: nil, validator: nil,
                   secret: false, env_fallback: nil, options: [], group_label: nil)
        key = key.to_s
        raise ArgumentError, "invalid platform setting key #{key.inspect}" unless KEY_FORMAT.match?(key)
        raise ArgumentError, "unsupported platform setting type #{type.inspect}" unless TYPES.include?(type)
        raise ArgumentError, 'validator must respond to call' if validator && !validator.respond_to?(:call)

        definitions[key] = Definition.new(key:, type:, label:, hint:, default:, pattern:, validator:, secret:,
                                          env_fallback:, options: Array(options), group_label:)
      end

      def find(key) = definitions[key.to_s]
      def any? = definitions.any?
      def grouped = definitions.values.group_by(&:group)

      def reset!
        @definitions = {}
      end
    end
  end

  class << self
    def register_platform_setting(key, **)
      PlatformSettingsRegistry.register(key, **)
    end

    def registered_platform_settings
      PlatformSettingsRegistry.definitions.values
    end
  end
end
