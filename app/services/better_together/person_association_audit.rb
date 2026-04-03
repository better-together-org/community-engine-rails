# frozen_string_literal: true

module BetterTogether
  # Verifies that person/user references are declared in the deletion manifest and reverse associations.
  class PersonAssociationAudit
    class << self
      def call
        new.call
      end
    end

    def call
      {
        missing_manifest_entries: discovered_references.reject { |reference| covered_by_manifest?(reference) },
        stale_manifest_entries: manifest_specific_references.reject { |entry| manifest_reference_exists?(entry) },
        missing_reverse_associations: manifest_reverse_references.reject { |entry| reverse_association_declared?(entry) }
      }
    end

    private

    def manifest_entries
      BetterTogether::PersonDeletionManifest.entries
    end

    def manifest_specific_references
      manifest_entries.select { |entry| entry.fetch('kind') == 'model_reference' }
    end

    def manifest_reverse_references
      manifest_entries.select { |entry| entry['reverse_association'].present? }
    end

    # rubocop:disable Metrics/AbcSize
    def discovered_references
      Rails.application.eager_load!

      ApplicationRecord.descendants
                       .select { |klass| klass.name&.start_with?('BetterTogether::') }
                       .reject(&:abstract_class?)
                       .flat_map do |klass|
        klass.reflect_on_all_associations(:belongs_to).filter_map do |reflection|
          next unless person_or_user_reference?(klass, reflection)

          {
            key: "#{klass.name}##{reflection.name}",
            model: klass.name,
            association: reflection.name.to_s
          }
        end
      end
    end
    # rubocop:enable Metrics/AbcSize

    def covered_by_manifest?(reference)
      return true if manifest_specific_references.any? { |entry| entry.fetch('key') == reference.fetch(:key) }

      reference.fetch(:association) == 'creator' &&
        manifest_entries.any? { |entry| entry.fetch('kind') == 'creatable_creator_reference' }
    end

    def reverse_association_declared?(entry)
      entry.fetch('owner').classify.constantize.reflect_on_association(entry.fetch('reverse_association').to_sym).present?
    rescue NameError
      owner_class_name = entry.fetch('owner') == 'person' ? 'BetterTogether::Person' : 'BetterTogether::User'
      owner_class_name.constantize.reflect_on_association(entry.fetch('reverse_association').to_sym).present?
    end

    def manifest_reference_exists?(entry)
      model_class = entry.fetch('model').constantize
      model_class.reflect_on_association(entry.fetch('association').to_sym)&.macro == :belongs_to
    rescue NameError
      false
    end

    def person_or_user_reference?(klass, reflection)
      target_class_name = reflection.options[:class_name]
      return true if %w[BetterTogether::Person BetterTogether::User].include?(target_class_name)

      foreign_keys_for(klass).any? do |foreign_key_definition|
        foreign_key_definition.options[:column].to_s == reflection.foreign_key.to_s &&
          %w[better_together_people better_together_users].include?(foreign_key_definition.to_table)
      end
    end

    def foreign_keys_for(klass)
      klass.connection.foreign_keys(klass.table_name)
    rescue StandardError
      []
    end
  end
end
