# frozen_string_literal: true

# app/models/concerns/seedable.rb
require_dependency 'better_together/seed'

module BetterTogether
  # Defines interface allowing models to implement import/export as seed feature
  module Seedable
    extend ActiveSupport::Concern

    # ----------------------------------------
    # This submodule holds methods that we want on the ActiveRecord::Relation
    # e.g., Wizard.where(...).export_collection_as_seed(...)
    # ----------------------------------------
    module RelationMethods
      def export_collection_as_seed(root_key: BetterTogether::Seed::DEFAULT_ROOT_KEY, version: '1.0')
        # `self` is the AR relation. We call the model’s class method with this scope’s records.
        klass = self.klass
        klass.export_collection_as_seed(to_a, root_key: root_key, version: version)
      end

      def export_collection_as_seed_yaml(root_key: BetterTogether::Seed::DEFAULT_ROOT_KEY, version: '1.0')
        klass = self.klass
        klass.export_collection_as_seed_yaml(to_a, root_key: root_key, version: version)
      end
    end

    included do
      has_many :seeds, as: :seedable, class_name: 'BetterTogether::Seed', dependent: :nullify
    end

    # ----------------------------------------
    # Overridable method: convert this record into a hash for the seed's payload
    # ----------------------------------------
    def plant
      {
        model_class: self.class.name,
        record_id: id
        # Add more fields if needed, e.g., name:, etc.
      }
    end

    # ----------------------------------------
    # Export single record and create a seed
    # ----------------------------------------
    # rubocop:todo Metrics/MethodLength
    def export_as_seed( # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      root_key: BetterTogether::Seed::DEFAULT_ROOT_KEY,
      version: '1.0',
      seed_description: "Seed data for #{self.class.name} record"
    )
      seed_hash = {
        root_key => {
          version: version,
          seed: {
            created_at: Time.now.utc.iso8601,
            description: seed_description,
            origin: {
              contributors: [],
              platforms: [],
              license: 'LGPLv3',
              usage_notes: 'Generated by BetterTogether::Seedable'
            }
          },
          record: plant
        }
      }

      # Must be persisted to create child records
      unless persisted?
        raise ActiveRecord::RecordNotSaved, "Can't export seed from unsaved record (#{self.class.name}). Save it first."
      end

      seeds.create!(
        type: 'BetterTogether::Seed',
        identifier: "#{self.class.name.demodulize.underscore}-#{id}-#{SecureRandom.hex(4)}",
        version: version,
        created_by: 'SystemExport',
        seeded_at: Time.now,
        seedable_type: self.class.name,
        seedable_id: id,
        description: seed_description,
        origin: { 'export_root_key' => root_key },
        payload: seed_hash
      )

      seed_hash
    end
    # rubocop:enable Metrics/MethodLength

    def export_as_seed_yaml(**)
      export_as_seed(**).deep_stringify_keys.to_yaml
    end

    # ----------------------------------------
    # Class Methods - Exporting Collections
    # ----------------------------------------
    class_methods do # rubocop:todo Metrics/BlockLength
      # Overriding `.relation` ensures that *every* AR query for this model
      # is extended with `RelationMethods`.
      def relation
        super.extending(RelationMethods)
      end

      # Overload with array of records
      def export_collection_as_seed( # rubocop:todo Metrics/MethodLength
        records,
        root_key: BetterTogether::Seed::DEFAULT_ROOT_KEY,
        version: '1.0'
      )
        seed_hash = {
          root_key => {
            version: version,
            seed: {
              created_at: Time.now.utc.iso8601,
              description: "Seed data for a collection of #{name} records",
              origin: {
                contributors: [],
                platforms: [],
                license: 'LGPLv3',
                usage_notes: 'Generated by BetterTogether::Seedable'
              }
            },
            records: records.map(&:plant)
          }
        }

        BetterTogether::Seed.create!(
          type: 'BetterTogether::Seed',
          identifier: "#{name.demodulize.underscore}-collection-#{SecureRandom.hex(4)}",
          version: version,
          created_by: 'SystemExport',
          seeded_at: Time.now,
          seedable_type: name,  # e.g. "BetterTogether::Wizard"
          seedable_id: nil,     # no single record
          description: "Collection export of #{name} (size: #{records.size})",
          origin: { 'export_root_key' => root_key },
          payload: seed_hash
        )

        seed_hash
      end

      def export_collection_as_seed_yaml(records, **opts)
        export_collection_as_seed(records, **opts).deep_stringify_keys.to_yaml
      end
    end
  end
end
