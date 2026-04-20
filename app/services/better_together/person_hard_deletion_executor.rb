# frozen_string_literal: true

module BetterTogether
  # Executes a full destructive cleanup for safe prelaunch account purges.
  # rubocop:disable Metrics/ClassLength
  class PersonHardDeletionExecutor
    DELETE_ONLY_CLASSES = [::BetterTogether::ConversationParticipant].freeze
    MEMBERSHIP_MODELS = [
      'BetterTogether::PersonCommunityMembership',
      'BetterTogether::PersonPlatformMembership'
    ].freeze

    class << self
      def call(person:, person_deletion_request: nil, reviewed_by: nil, reason: nil)
        new(person:, person_deletion_request:, reviewed_by:, reason:).call
      end
    end

    attr_reader :person, :person_deletion_request, :reviewed_by, :reason

    def initialize(person:, person_deletion_request: nil, reviewed_by: nil, reason: nil)
      @person = person
      @person_deletion_request = person_deletion_request
      @reviewed_by = reviewed_by
      @reason = reason
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def call
      inventory = BetterTogether::PersonHardDeletionInventory.call(person:)
      audit = nil

      ActiveRecord::Base.transaction do
        approve_request_if_needed!
        audit = build_audit(inventory)
        prepare_owned_belongs_to_cycles!(inventory)
        complete_audit!(audit, execute_inventory(inventory))
      end

      audit.reload
    rescue StandardError => e
      audit&.update!(
        status: :failed,
        error_message: e.message,
        execution_snapshot: (audit.execution_snapshot || {}).merge('backtrace' => Array(e.backtrace).first(20)),
        failed_at: Time.current
      )
      raise
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    private

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def build_audit(inventory)
      BetterTogether::PersonPurgeAudit.create!(
        person:,
        person_deletion_request:,
        reviewed_by: persistent_reviewer,
        user_email_snapshot: person.user&.email,
        person_identifier_snapshot: person.identifier,
        person_name_snapshot: person.name,
        requested_reason_snapshot: person_deletion_request&.requested_reason || reason,
        reviewer_notes_snapshot: reason,
        requested_at: person_deletion_request&.requested_at || Time.current,
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
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

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
      unlock_protected_records(BetterTogether::Calendar.where(creator_id: person.id))
      unlock_protected_records(BetterTogether::Calendar.where(community_id: owned_community.id)) if owned_community
      prepare_owned_community!(owned_community) if owned_community
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
        destroyed_entries:,
        verification: verification_snapshot(inventory)
      }
    end

    def ordered_entries(inventory)
      self_entries, non_self_entries = inventory.fetch(:entries).partition do |entry|
        %w[user person].include?(entry.fetch(:key))
      end
      deferred_entries, immediate_entries = non_self_entries.partition do |entry|
        deferred_until_after_person?(entry)
      end

      immediate_entries + self_entries.sort_by { |entry| entry.fetch(:key) == 'user' ? 0 : 1 } + deferred_entries
    end

    def destroy_record(record)
      record.destroy!
      'destroy'
    end

    def deferred_until_after_person?(entry)
      return true if entry.fetch(:kind) == 'owned_primary_community'

      person && belongs_to_targets.any? { |target| entry_targets?(entry, target) }
    end

    def persistent_reviewer
      return unless reviewed_by&.persisted?
      return unless reviewed_by.id != person.id

      reviewed_by
    end

    def owned_community_entry(inventory)
      community_entry = inventory.fetch(:entries).find { |entry| entry.fetch(:key) == 'person.owned_primary_community' }
      return unless community_entry

      BetterTogether::Community.find_by(id: community_entry.fetch(:ids), creator_id: person.id)
    end

    def entry_model(entry)
      entry.fetch(:model).constantize
    end

    def unprocessed_ids(entry, model_class, processed)
      Array(entry.fetch(:ids)).reject { |id| processed[[model_class.name, id.to_s]] }
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def destroy_entry(entry, model_class, scoped_ids, processed)
      if delete_only_entry?(entry, model_class)
        cleanup_notifications_for_deleted_memberships(entry, model_class, scoped_ids)
        processed_ids(processed, model_class.name, scoped_ids)

        model_class.where(id: scoped_ids).delete_all

        return entry.slice(:key, :kind, :model, :count, :ids, :original_action).merge(
          execution_methods: ['delete']
        )
      end

      execution_methods = model_class.where(id: scoped_ids).find_each.with_object([]) do |record, methods|
        unlock_protected_record!(record)
        processed[[record.class.name, record.id.to_s]] = true
        methods << destroy_record(record)
      end

      entry.slice(:key, :kind, :model, :count, :ids, :original_action).merge(
        execution_methods: execution_methods.uniq
      )
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def delete_only_entry?(entry, model_class)
      entry.fetch(:action) == 'delete' || DELETE_ONLY_CLASSES.include?(model_class)
    end

    def cleanup_notifications_for_deleted_memberships(entry, model_class, scoped_ids)
      return unless membership_entry?(entry, model_class)

      Noticed::Event.where(record_type: model_class.name, record_id: scoped_ids).find_each do |event|
        event.notifications.delete_all
        event.delete
      end
    end

    def membership_entry?(entry, model_class)
      MEMBERSHIP_MODELS.include?(model_class.name) || MEMBERSHIP_MODELS.include?(entry.fetch(:model))
    end

    def processed_ids(processed, model_name, ids)
      ids.each do |id|
        processed[[model_name, id.to_s]] = true
      end
    end

    def approve_request_if_needed!
      return unless person_deletion_request&.pending?

      person_deletion_request.approve!(
        reviewed_by: reviewed_by || person,
        reviewer_notes: reason
      )
    end

    def prepare_owned_community!(community)
      updates = {}
      updates[:creator_id] = nil if community.creator_id.present?
      updates[:protected] = false if community.respond_to?(:protected?) && community.protected?
      community.update!(updates) if updates.any?
    end

    def unlock_protected_records(scope)
      scope.find_each { |record| unlock_protected_record!(record) }
    end

    def unlock_protected_record!(record)
      return unless record.respond_to?(:protected?) && record.protected?

      record.update_column(:protected, false)
    end

    def verification_snapshot(inventory)
      inventory.fetch(:entries).each_with_object({}) do |entry, verification|
        remaining_count = entry_model(entry).where(id: entry.fetch(:ids)).count
        verification[entry.fetch(:key)] = {
          'remaining_count' => remaining_count,
          'completed' => remaining_count.zero?
        }
      end
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
