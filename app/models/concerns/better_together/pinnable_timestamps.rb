# frozen_string_literal: true

module BetterTogether
  # Lets an import or backfill keep the original dates of a record. The API sets `pin_timestamps_to_creation` when it
  # receives created_at (updated_at then equals it) and `pinned_updated_at` when it receives updated_at. Saving
  # attachments, blocks or a cover touches the record again, so the date is written once more after commit with
  # update_columns, which bypasses timestamps. Unpinned records behave as usual.
  module PinnableTimestamps
    extend ActiveSupport::Concern

    included do
      attr_accessor :pin_timestamps_to_creation, :pinned_updated_at

      after_commit :pin_updated_at_to_created_at, on: :create, if: :pin_timestamps_to_creation
      after_commit :apply_pinned_updated_at, on: %i[create update], if: :pinned_updated_at
    end

    private

    def pin_updated_at_to_created_at
      update_columns(updated_at: created_at) # rubocop:disable Rails/SkipsModelValidations
    end

    def apply_pinned_updated_at
      update_columns(updated_at: pinned_updated_at) # rubocop:disable Rails/SkipsModelValidations
      self.pinned_updated_at = nil
    end
  end
end
