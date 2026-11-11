# frozen_string_literal: true

module BetterTogether
  module Quotas
    # Default limits for lazily-created Quota rows. YAML-driven (config/quota_defaults.yml,
    # merged with other engines' and the host app's files of the same name) with a
    # per-platform override stored in Platform#settings['quota_default_limits'].
    # Behaviour stays in the Quotas::Type classes; only the numbers live here.
    module Defaults
      OWNER_KINDS = %w[person community platform].freeze
      FILE_NAME = 'quota_defaults.yml'

      class InvalidDefaultsError < StandardError; end

      class << self
        # Limit for a new Quota: platform override, then merged YAML. Nil when no
        # level defines the type and kind.
        def for(type:, owner:)
          kind = owner_kind(owner)
          platform_value(settings_platform(owner), type, kind) || yaml_value(type, kind)
        end

        def yaml_value(type, kind)
          value = table.dig(type.to_s, kind.to_s)
          value.nil? ? nil : Integer(value)
        end

        def platform_value(platform, type, kind)
          return nil unless platform.respond_to?(:quota_default_limits)

          value = platform.quota_default_limits.dig(type.to_s, kind.to_s)
          value.nil? ? nil : Integer(value)
        end

        def owner_kind(owner)
          case owner
          when BetterTogether::Person then 'person'
          when BetterTogether::Community then 'community'
          else 'platform'
          end
        end

        # The platform whose settings may override the default: the owner itself for a
        # Platform, otherwise the platform the person/community lives on.
        def settings_platform(owner)
          return owner if owner.is_a?(BetterTogether::Platform)

          (owner.respond_to?(:platform) && owner.platform) || Current.platform
        end

        # Cleans a platform's override hash: known quota types, known owner kinds,
        # non-negative integers only; blank entries mean "inherit" and are dropped.
        def sanitize_overrides(value)
          return {} unless value.respond_to?(:each_pair)

          value.each_pair.with_object({}) do |(type, by_kind), sanitized|
            next unless Type.keys.include?(type.to_s) && by_kind.respond_to?(:each_pair)

            limits = sanitize_kinds(by_kind)
            sanitized[type.to_s] = limits if limits.any?
          end
        end

        # The merged type => kind => integer table (no platform overrides).
        def table
          @table ||= load_table.freeze
        end

        def reset!
          @table = nil
        end

        # Files in merge order: this engine, other engines (by name), then the host.
        def files
          engines = Rails::Engine.descendants
                                 .reject { |engine| engine == BetterTogether::Engine || engine <= Rails::Application }
                                 .sort_by(&:engine_name)
          ([BetterTogether::Engine] + engines).map { |engine| engine.root.join('config', FILE_NAME) } +
            [Rails.root.join('config', FILE_NAME)]
        end

        private

        def sanitize_kinds(by_kind)
          by_kind.each_pair.with_object({}) do |(kind, limit), result|
            result[kind.to_s] = limit.to_i if OWNER_KINDS.include?(kind.to_s) && limit.to_s.match?(/\A\d+\z/)
          end
        end

        def load_table
          files.uniq.select(&:exist?).each_with_object({}) do |file, merged|
            deep_merge!(merged, normalize(YAML.safe_load_file(file) || {}, file))
          end
        end

        def normalize(raw, file)
          quotas = raw.fetch('quotas', {})
          raise InvalidDefaultsError, "#{file}: 'quotas' must be a mapping" unless quotas.is_a?(Hash)

          quotas.to_h do |type, kinds|
            raise InvalidDefaultsError, "#{file}: #{type} must be a mapping" unless kinds.is_a?(Hash)

            [type.to_s, kinds.to_h { |kind, limit| [kind.to_s, validate_limit!(file, type, kind, limit)] }]
          end
        end

        def validate_limit!(file, type, kind, limit)
          unless OWNER_KINDS.include?(kind.to_s)
            raise InvalidDefaultsError, "#{file}: #{type}.#{kind} is not an owner kind (#{OWNER_KINDS.join(', ')})"
          end
          raise InvalidDefaultsError, "#{file}: #{type}.#{kind} must be a non-negative integer" unless limit.is_a?(Integer) && limit >= 0

          limit
        end

        def deep_merge!(base, other)
          other.each { |type, kinds| (base[type] ||= {}).merge!(kinds) }
          base
        end
      end
    end
  end
end
