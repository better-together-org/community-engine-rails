# frozen_string_literal: true

module BetterTogether
  # Loads the canonical feature gate catalog shipped with the engine.
  class FeatureRegistry
    VALID_ROLLOUTS = %w[off alpha beta stable].freeze
    VALID_SURFACES = %w[ui api both].freeze

    class << self
      def all
        @all ||= load_registry
      end

      def fetch(key)
        all.fetch(key.to_s)
      end

      def keys
        all.keys
      end

      def reset!
        @all = nil
      end

      private

      def load_registry
        raw = YAML.safe_load_file(BetterTogether::Engine.root.join('config/feature_gates.yml')) || {}
        entries = Array(raw.fetch('features', []))

        entries.each_with_object({}) do |entry, registry|
          normalized = normalize_entry(entry)
          registry[normalized.fetch(:key)] = normalized.freeze
        end.freeze
      end

      def normalize_entry(entry)
        normalized = entry.deep_symbolize_keys
        key = normalized.fetch(:key).to_s
        rollout = normalized.fetch(:default_rollout).to_s
        surface = normalized.fetch(:owner_surface).to_s

        validate_entry!(key:, rollout:, surface:)

        normalized.merge(key:, default_rollout: rollout, owner_surface: surface)
      end

      def validate_entry!(key:, rollout:, surface:)
        raise ArgumentError, "invalid rollout '#{rollout}' for feature '#{key}'" unless VALID_ROLLOUTS.include?(rollout)
        raise ArgumentError, "invalid surface '#{surface}' for feature '#{key}'" unless VALID_SURFACES.include?(surface)
      end
    end
  end
end
