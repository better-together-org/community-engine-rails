# frozen_string_literal: true

module BetterTogether
  # Loads the canonical non-monetary benefit-credit catalog shipped with the
  # engine. Mirrors FeatureRegistry's YAML-backed load/validate/freeze shape —
  # a Billing::BenefitCredit's benefit_key must be a known key here.
  class BenefitRegistry
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
        find(key)&.fetch(:name) || "Unknown benefit (#{key})"
      end

      def reset!
        @all = nil
      end

      private

      def load_registry
        raw = YAML.safe_load_file(BetterTogether::Engine.root.join('config/benefit_registry.yml')) || {}
        entries = Array(raw.fetch('benefits', []))

        entries.each_with_object({}) do |entry, registry|
          normalized = normalize_entry(entry)
          registry[normalized.fetch(:key)] = normalized.freeze
        end.freeze
      end

      def normalize_entry(entry)
        normalized = entry.deep_symbolize_keys
        key = normalized.fetch(:key).to_s

        raise ArgumentError, "benefit registry entry missing key: #{entry.inspect}" if key.blank?

        normalized.merge(key:)
      end
    end
  end
end
