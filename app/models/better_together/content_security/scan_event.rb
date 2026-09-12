# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Records a single scanner execution attempt and its outcome for an Item.
    class ScanEvent < PlatformRecord
      self.table_name = 'better_together_content_security_scan_events'

      enum :status, {
        started: 'started',
        completed: 'completed',
        failed: 'failed',
        skipped: 'skipped'
      }, prefix: true

      belongs_to :item, class_name: 'BetterTogether::ContentSecurity::Item', inverse_of: :scan_events

      has_many :findings, class_name: 'BetterTogether::ContentSecurity::Finding', dependent: :nullify, inverse_of: :scan_event

      validates :status, :plane, :scanner_name, :started_at, presence: true
    end
  end
end
