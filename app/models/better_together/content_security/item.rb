# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Tracks the lifecycle of a scanned attachment blob, from pending scan through clean/quarantined/blocked.
    class Item < ApplicationRecord
      self.table_name = 'better_together_content_security_items'

      enum :lifecycle_state, {
        pending_scan: 'pending_scan',
        clean: 'clean',
        review_required: 'review_required',
        quarantined: 'quarantined',
        blocked: 'blocked',
        override_released: 'override_released'
      }, prefix: true

      enum :aggregate_verdict, {
        pending_scan: 'pending_scan',
        clean: 'clean',
        review_required: 'review_required',
        quarantined: 'quarantined',
        blocked: 'blocked',
        override_released: 'override_released'
      }, prefix: true

      belongs_to :blob, class_name: 'ActiveStorage::Blob'
      belongs_to :attachable, polymorphic: true
      belongs_to :safety_case, class_name: 'BetterTogether::Safety::Case', optional: true

      has_many :scan_events, class_name: 'BetterTogether::ContentSecurity::ScanEvent', dependent: :destroy, inverse_of: :item
      has_many :findings, class_name: 'BetterTogether::ContentSecurity::Finding', dependent: :destroy, inverse_of: :item

      validates :attachment_name, :source_surface, :lifecycle_state, :aggregate_verdict, presence: true

      scope :for_attachment, lambda { |attachable, attachment_name|
        where(attachable:, attachment_name: attachment_name.to_s)
      }

      def releasable?
        lifecycle_state_clean? || lifecycle_state_override_released?
      end
    end
  end
end
