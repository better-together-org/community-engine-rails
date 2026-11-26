# frozen_string_literal: true

module BetterTogether
  module Billing
    # Records that one person was notified of one thing, so it never happens twice (a replayed
    # webhook, a retried job, a double click). Written before the notification is sent, in the
    # same transaction as the notification itself.
    class NotificationReceipt < ApplicationRecord
      include PlatformBound

      self.table_name = 'better_together_billing_notification_receipts'

      belongs_to :recipient, class_name: 'BetterTogether::Person', optional: false

      validates :kind, :audience, :dedupe_key, presence: true
      validates :dedupe_key, uniqueness: { scope: %i[platform_id recipient_id kind] }
    end
  end
end
