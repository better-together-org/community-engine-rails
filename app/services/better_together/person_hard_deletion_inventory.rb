# frozen_string_literal: true

module BetterTogether
  # Builds a fully destructive inventory for prelaunch account cleanup.
  class PersonHardDeletionInventory
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
      explicit_entries = transform_explicit_entries(BetterTogether::PersonDeletionInventory.call(person:).fetch(:entries))
      reflection_entries = reflected_owner_entries

      {
        generated_at: Time.current.iso8601,
        deletion_mode: 'hard_delete',
        person_id: person.id,
        user_id: user&.id,
        entries: deduplicate_entries(explicit_entries + reflection_entries)
      }
    end

    private

    def reflected_owner_entries
      [
        reflected_entries_for(owner: user, owner_label: 'user'),
        reflected_entries_for(owner: person, owner_label: 'person')
      ].flatten
    end

    def transform_explicit_entries(entries)
      entries.map do |entry|
        entry.merge(
          action: 'destroy',
          original_action: entry.fetch(:action)
        )
      end
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def reflected_entries_for(owner:, owner_label:)
      return [] unless owner

      owner.class.reflect_on_all_associations.filter_map do |reflection|
        next unless includable_reflection?(reflection)

        records = extract_records(owner, reflection)
        next if records.empty?

        {
          key: "#{owner_label}.#{reflection.name}",
          action: 'destroy',
          original_action: 'destroy',
          kind: 'owner_reflection',
          model: records.first.class.name,
          count: records.size,
          ids: records.map { |record| record.id.to_s },
          reflection: reflection.name.to_s,
          dependent: reflection.options[:dependent].to_s
        }
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def includable_reflection?(reflection)
      reflection.options[:through].blank? && direct_destroyable_reflection?(reflection)
    end

    def direct_destroyable_reflection?(reflection)
      return false unless %i[has_one has_many].include?(reflection.macro)

      reflection.options[:dependent].present?
    end

    def extract_records(owner, reflection)
      value = owner.public_send(reflection.name)
      value.respond_to?(:to_ary) ? value.to_a.compact : Array.wrap(value).compact
    rescue StandardError
      []
    end

    def deduplicate_entries(entries)
      seen = {}

      entries.each_with_object([]) do |entry, deduped|
        normalized_ids = Array(entry.fetch(:ids)).map(&:to_s).sort
        identity = [entry.fetch(:model), normalized_ids]
        next if normalized_ids.empty? || seen[identity]

        seen[identity] = true
        deduped << entry.merge(count: normalized_ids.size, ids: normalized_ids)
      end
    end
  end
end
