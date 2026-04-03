# frozen_string_literal: true

module BetterTogether
  # Minimal export contract for records that can be carried as CE seeds.
  module Seedable
    extend ActiveSupport::Concern

    # Proxy to class-level export for ActiveRecord relation chains.
    module RelationMethods
      def export_collection_as_seed(root_key: BetterTogether::Seed::DEFAULT_ROOT_KEY, version: '1.0')
        klass.export_collection_as_seed(to_a, root_key:, version:)
      end
    end

    included do
      has_many :seeds, as: :seedable, class_name: 'BetterTogether::Seed', dependent: :nullify
    end

    def plant
      {
        model_class: self.class.name,
        record_id: id
      }
    end

    # ----------------------------------------
    # Export single record and create a seed
    # ----------------------------------------
    def export_as_seed( # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      root_key: BetterTogether::Seed::DEFAULT_ROOT_KEY,
      version: '1.0',
      seed_description: "Seed data for #{self.class.name} record",
      creator_id: nil
    )
      ::BetterTogether::Seeds::Builder.call(
        subject: self,
        profile: person_self_export?(creator_id) ? 'personal_export' : 'manual_export',
        context: { description: seed_description },
        persist: true,
        creator_id:,
        root_key:,
        version:
      ).seed_hash
    end

    def export_as_seed_yaml(**)
      export_as_seed(**).deep_stringify_keys.to_yaml
    end

    private

    def person_self_export?(creator_id)
      is_a?(::BetterTogether::Person) && creator_id.present? && creator_id.to_s == id.to_s
    end

    class_methods do
      def relation
        super.extending(RelationMethods)
      end

      def export_collection_as_seed(records, root_key: BetterTogether::Seed::DEFAULT_ROOT_KEY, version: '1.0')
        { root_key => build_seed_envelope(records, version) }
      end

      def export_collection_as_seed_yaml(records, **)
        export_collection_as_seed(records, **).deep_stringify_keys.to_yaml
      end

      private

      def build_seed_envelope(records, version)
        { version:, seed: build_seed_metadata, records: records.map(&:plant) }
      end

      def build_seed_metadata
        {
          type: 'BetterTogether::Seed',
          identifier: "#{name.demodulize.underscore}-collection-#{SecureRandom.hex(6)}",
          created_by: 'SystemExport',
          created_at: Time.current.utc.iso8601,
          description: "Seed data for a collection of #{name} records",
          origin: { contributors: [], platforms: [], lane: 'manual_export' },
          seedable_type: name
        }
      end
    end
  end
end
