# frozen_string_literal: true

module BetterTogether
  # Executes a full destructive cleanup for safe prelaunch account purges.
  # rubocop:disable Metrics/ClassLength
  class PersonHardDeletionExecutor
    DELETE_ONLY_CLASSES = [::BetterTogether::ConversationParticipant].freeze

    class << self
      def call(person:, reviewed_by: nil, reason: nil)
        new(person:, reviewed_by:, reason:).call
      end
    end

    attr_reader :person, :reviewed_by, :reason

    def initialize(person:, reviewed_by: nil, reason: nil)
      @person = person
      @reviewed_by = reviewed_by
      @reason = reason
    end

    # rubocop:disable Metrics/MethodLength
    def call
      inventory = BetterTogether::PersonHardDeletionInventory.call(person:)
      audit = build_audit(inventory)

      ActiveRecord::Base.transaction do
        prepare_owned_belongs_to_cycles!(inventory)
        complete_audit!(audit, execute_inventory(inventory))
      end

      audit
    rescue StandardError => e
      audit&.update!(
        status: :failed,
        error_message: e.message,
        execution_snapshot: (audit.execution_snapshot || {}).merge('backtrace' => Array(e.backtrace).first(20)),
        failed_at: Time.current
      )
      raise
    end
    # rubocop:enable Metrics/MethodLength

    private

    # rubocop:disable Metrics/MethodLength
    def build_audit(inventory)
      BetterTogether::PersonPurgeAudit.create!(
        reviewed_by: persistent_reviewer,
        user_email_snapshot: person.user&.email,
        person_identifier_snapshot: person.identifier,
        person_name_snapshot: person.name,
        requested_reason_snapshot: reason,
        reviewer_notes_snapshot: reason,
        requested_at: Time.current,
        reviewed_at: Time.current,
        started_at: Time.current,
        status: :running,
        inventory_snapshot: inventory,
        execution_snapshot: {
          'deletion_mode' => 'hard_delete',
          'destroyed_entries' => []
        }
      )
    end
    # rubocop:enable Metrics/MethodLength

    def complete_audit!(audit, execution_snapshot)
      audit.update!(
        status: :completed,
        execution_snapshot: execution_snapshot,
        completed_at: Time.current
      )
    end

    def prepare_owned_belongs_to_cycles!(inventory)
      return unless person&.persisted?

      owned_community = owned_community_entry(inventory)
      return unless owned_community && person.community_id == owned_community.id

      person.update_columns(community_id: fallback_community!(owned_community).id, updated_at: Time.current)
    end

    def execute_inventory(inventory)
      processed = {}
      destroyed_entries = []

      ordered_entries(inventory).each do |entry|
        model_class = entry_model(entry)
        scoped_ids = unprocessed_ids(entry, model_class, processed)
        next if scoped_ids.empty?

        destroyed_entries << destroy_entry(entry, model_class, scoped_ids, processed)
      end

      {
        deletion_mode: 'hard_delete',
        destroyed_entries:
      }
    end

    def ordered_entries(inventory)
      self_entries, non_self_entries = inventory.fetch(:entries).partition do |entry|
        %w[user person].include?(entry.fetch(:key))
      end

      deferred_entries, early_entries = non_self_entries.partition { |entry| deferred_until_after_person?(entry) }

      early_entries + self_entries.sort_by { |entry| entry.fetch(:key) == 'user' ? 0 : 1 } + deferred_entries
    end

    def destroy_record(record, entry)
      if delete_only_record?(record, entry)
        record.delete
        return 'delete'
      end

      record.destroy!
      'destroy'
    rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::StatementInvalid, NoMethodError
      record.delete
      'delete_fallback'
    end

    def delete_only_record?(record, entry)
      return true if %w[user person].include?(entry.fetch(:key))

      DELETE_ONLY_CLASSES.any? { |klass| record.instance_of?(klass) }
    end

    def deferred_until_after_person?(entry)
      person && belongs_to_targets.any? { |target| entry_targets?(entry, target) }
    end

    def persistent_reviewer
      return unless reviewed_by&.persisted?
      return unless reviewed_by.id != person.id

      reviewed_by
    end

    def owned_community_entry(inventory)
      community_entry = inventory.fetch(:entries).find { |entry| entry.fetch(:model) == 'BetterTogether::Community' }
      return unless community_entry

      BetterTogether::Community.find_by(id: community_entry.fetch(:ids), creator_id: person.id)
    end

    def fallback_community!(owned_community)
      BetterTogether::Community.where.not(id: owned_community.id).first ||
        raise(ActiveRecord::RecordNotFound, 'No fallback community available to detach person before hard delete')
    end

    def entry_model(entry)
      entry.fetch(:model).constantize
    end

    def unprocessed_ids(entry, model_class, processed)
      Array(entry.fetch(:ids)).reject { |id| processed[[model_class.name, id.to_s]] }
    end

    def destroy_entry(entry, model_class, scoped_ids, processed)
      execution_methods = model_class.where(id: scoped_ids).find_each.with_object([]) do |record, methods|
        processed[[record.class.name, record.id.to_s]] = true
        methods << destroy_record(record, entry)
      end

      entry.slice(:key, :kind, :model, :count, :ids, :original_action).merge(
        execution_methods: execution_methods.uniq
      )
    end

    def belongs_to_targets
      person.class.reflect_on_all_associations(:belongs_to).filter_map do |reflection|
        person.public_send(reflection.name)
      end
    end

    def entry_targets?(entry, target)
      target.instance_of?(entry_model(entry)) && Array(entry.fetch(:ids)).map(&:to_s).include?(target.id.to_s)
    end
  end
  # rubocop:enable Metrics/ClassLength
end
