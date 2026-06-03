# frozen_string_literal: true

module BetterTogether
  # Executes the mixed-policy GDPR deletion flow for reviewed account deletion requests.
  # rubocop:disable Metrics/ClassLength
  class PersonDeletionExecutor
    class << self
      def call(person_deletion_request:, reviewed_by: nil, reviewer_notes: nil)
        new(
          person_deletion_request:,
          reviewed_by:,
          reviewer_notes:
        ).call
      end
    end

    attr_reader :person_deletion_request, :person, :user, :reviewed_by, :reviewer_notes

    def initialize(person_deletion_request:, reviewed_by: nil, reviewer_notes: nil)
      @person_deletion_request = person_deletion_request
      @person = person_deletion_request.person
      @user = person.user
      @reviewed_by = reviewed_by
      @reviewer_notes = reviewer_notes
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def call
      inventory = BetterTogether::PersonDeletionInventory.call(person:)
      audit = build_audit(inventory)

      ActiveRecord::Base.transaction do
        approve_request_if_needed!
        execution_snapshot = execute_inventory(inventory)
        BetterTogether::PersonDeletionAnonymizer.call(person:)
        scrub_request_text!

        audit.update!(
          status: :completed,
          execution_snapshot: execution_snapshot,
          completed_at: Time.current
        )
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
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    private

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def build_audit(inventory)
      BetterTogether::PersonPurgeAudit.create!(
        person:,
        person_deletion_request:,
        reviewed_by:,
        user_email_snapshot: user&.email,
        person_identifier_snapshot: person.identifier,
        person_name_snapshot: person.name,
        requested_reason_snapshot: person_deletion_request.requested_reason,
        reviewer_notes_snapshot: reviewer_notes || person_deletion_request.reviewer_notes,
        requested_at: person_deletion_request.requested_at,
        reviewed_at: Time.current,
        started_at: Time.current,
        status: :running,
        inventory_snapshot: inventory,
        execution_snapshot: { 'destroyed_entries' => [] }
      )
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def approve_request_if_needed!
      return unless person_deletion_request.pending?

      person_deletion_request.approve!(
        reviewed_by: reviewed_by || person,
        reviewer_notes:
      )
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def execute_inventory(inventory)
      processed = {}
      destroyed_entries = []

      inventory.fetch(:entries).each do |entry|
        next unless entry.fetch(:action) == 'destroy'

        model_class = entry.fetch(:model).constantize
        ids = entry.fetch(:ids)
        scoped_ids = ids.reject { |id| processed[[model_class.name, id]] }
        records = model_class.where(id: scoped_ids)

        records.find_each do |record|
          processed[[record.class.name, record.id.to_s]] = true
          record.destroy!
        end

        destroyed_entries << entry.slice(:key, :action, :model, :count, :ids)
      end

      if user && !processed[[user.class.name, user.id.to_s]]
        user.destroy!
        destroyed_entries << {
          key: 'user',
          action: 'destroy',
          model: user.class.name,
          count: 1,
          ids: [user.id.to_s]
        }
      end

      {
        destroyed_entries:,
        anonymized_person_id: person.id.to_s
      }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def scrub_request_text!
      person_deletion_request.update!(
        requested_reason: nil,
        reviewer_notes: nil
      )
    end
  end
  # rubocop:enable Metrics/ClassLength
end
