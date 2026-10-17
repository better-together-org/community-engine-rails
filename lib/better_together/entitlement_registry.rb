# frozen_string_literal: true

module BetterTogether
  # Loads the canonical entitlement catalog shipped with the engine — what a
  # Billing::Plan may declare it grants, and how to resolve whether a holder
  # currently has it. Mirrors FeatureRegistry's load/validate/freeze shape.
  #
  # Each entry's `resolution` says which backing mechanism answers "does the
  # holder have this": `grant` checks Billing::Entitlement rows, `credit`
  # checks Billing::BenefitCredit's available balance. For `credit` entries,
  # the key must match the corresponding BenefitRegistry key — this registry
  # only asserts "this key exists and resolves via credit," it does not
  # duplicate BenefitRegistry's name/description.
  class EntitlementRegistry
    RESOLUTION_MODES = %w[grant credit].freeze

    class << self
      def all
        @all ||= load_registry
      end

      def find(key)
        all[key.to_s]
      end

      def fetch(key)
        all.fetch(key.to_s)
      end

      def keys
        all.keys
      end

      def name_for(key)
        find(key)&.fetch(:name) || "Unknown entitlement (#{key})"
      end

      def reset!
        @all = nil
      end

      private

      def load_registry
        raw = YAML.safe_load_file(BetterTogether::Engine.root.join('config/entitlement_registry.yml')) || {}
        entries = Array(raw.fetch('entitlements', []))

        entries.each_with_object({}) do |entry, registry|
          normalized = normalize_entry(entry)
          registry[normalized.fetch(:key)] = normalized.freeze
        end.freeze
      end

      def normalize_entry(entry)
        normalized = entry.deep_symbolize_keys
        key = normalized.fetch(:key).to_s
        resolution = normalized.fetch(:resolution).to_s

        validate_entry!(key:, resolution:)

        normalized.merge(key:, resolution:)
      end

      def validate_entry!(key:, resolution:)
        return if RESOLUTION_MODES.include?(resolution)

        raise ArgumentError, "invalid resolution '#{resolution}' for entitlement '#{key}'"
      end
    end
  end
end
