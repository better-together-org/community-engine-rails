# frozen_string_literal: true

module BetterTogether
  class PersonDeletionInventory
    class << self
      def call(person:)
        new(person:).call
      end
    end

    attr_reader :person, :user

    def initialize(person:)
      @person = person
      @user = person.user
    end

    def call
      {
        generated_at: Time.current.iso8601,
        person_id: person.id,
        user_id: user&.id,
        entries: manifest_entries.filter_map { |entry| snapshot_entry(entry) }
      }
    end

    private

    def manifest_entries
      BetterTogether::PersonDeletionManifest.entries
    end

    def snapshot_entry(entry)
      records = resolve_records(entry)
      return if records.empty?

      {
        key: entry.fetch('key'),
        action: entry.fetch('action'),
        kind: entry.fetch('kind'),
        model: records.first.class.name,
        count: records.size,
        ids: records.map { |record| record.id.to_s },
        concern: entry['concern'],
        reverse_association: entry['reverse_association']
      }
    end

    def resolve_records(entry)
      case entry.fetch('kind')
      when 'self'
        Array.wrap(owner_for(entry)).compact
      when 'owner_association'
        resolve_owner_association(entry)
      when 'model_reference'
        resolve_model_reference(entry)
      when 'creatable_creator_reference'
        resolve_creatable_creator_reference
      else
        raise ArgumentError, "Unsupported manifest entry kind: #{entry['kind']}"
      end
    end

    def resolve_owner_association(entry)
      owner = owner_for(entry)
      return [] unless owner

      value = owner.public_send(entry.fetch('association'))
      value.respond_to?(:to_ary) ? value.to_a.compact : Array.wrap(value).compact
    end

    def resolve_model_reference(entry)
      owner_record = owner_for(entry)
      return [] unless owner_record

      entry.fetch('model').constantize.where(entry.fetch('foreign_key') => owner_record.id).to_a
    end

    def resolve_creatable_creator_reference
      creatable_models.flat_map do |model_class|
        model_class.where(creator_id: person.id).to_a
      end
    end

    def creatable_models
      Rails.application.eager_load!

      ApplicationRecord.descendants
                       .select { |klass| klass.name&.start_with?('BetterTogether::') }
                       .reject(&:abstract_class?)
                       .select { |klass| klass.included_modules.include?(BetterTogether::Creatable) }
                       .select { |klass| klass.column_names.include?('creator_id') }
    end

    def owner_for(entry)
      case entry.fetch('owner')
      when 'person' then person
      when 'user' then user
      else
        raise ArgumentError, "Unsupported manifest owner: #{entry['owner']}"
      end
    end
  end
end
