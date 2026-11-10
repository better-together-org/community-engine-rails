# frozen_string_literal: true

module BetterTogether
  module Billing
    # The invoice or receipt of an order as a PDF, kept in storage as an Upload (so it is fetched through the Upload's
    # own download, not generated again). A new one is made when the figures change (a refund, a payment); the one it
    # replaces is kept, marked `superseded_at`, and only the current one of each kind is shown on the order.
    #
    # It is tied to its order by a composite foreign key, so it is always on the order's own platform.
    class OrderDocument < ApplicationRecord
      include PlatformBound
      include ParentBound

      self.table_name = 'better_together_billing_order_documents'

      KINDS = %w[invoice receipt].freeze

      belongs_to :order, class_name: 'BetterTogether::Billing::Order', inverse_of: :documents, optional: false
      belongs_to :upload, class_name: 'BetterTogether::Upload', optional: false

      validates :kind, inclusion: { in: KINDS }
      validates :fingerprint, :time_zone, :generated_at, presence: true
      validate :upload_on_the_orders_platform

      scope :current, -> { where(superseded_at: nil) }
      scope :of_kind, ->(kind) { where(kind: kind.to_s) }

      delegate :filename, :byte_size, to: :upload

      def current? = superseded_at.nil?

      private

      def billing_parent = order

      def upload_on_the_orders_platform
        errors.add(:upload, :platform_owner_mismatch) if upload && platform_id.present? && upload.platform_id != platform_id
      end
    end
  end
end
