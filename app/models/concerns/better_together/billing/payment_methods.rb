# frozen_string_literal: true

module BetterTogether
  module Billing
    # The ways a sale can be paid: one online processor, and/or methods outside a vendor (cash, cheque, e-transfer,
    # store credit) listed in `accepted_payment_methods`. Needs the columns `processor`, `accepted_payment_methods`
    # and `amount_cents`. Something that costs money needs at least one way to pay. Shared by everything sold.
    module PaymentMethods
      extend ActiveSupport::Concern

      # Not part of the processor-backed price, so editable at any time.
      PAYMENT_METHOD_PARAMS = { accepted_payment_methods: [] }.freeze

      included do
        before_validation :normalize_payment_fields

        validate :payable_some_way
        validate :accepted_methods_are_not_online_processors
      end

      class_methods do
        # An installed method Community Engine settles itself (settlement manual or internal).
        def local_method?(name) = Billing.local_method?(name)
      end

      # Held by an online payment processor (as opposed to paid only by cash, cheque,
      # e-transfer or store credit).
      def online? = processor.present?

      # Every way this can be paid: its online processor, then the others.
      def payment_methods = [processor.presence, *accepted_payment_methods].compact.uniq

      private

      # An empty processor means "none", stored as NULL like every other absent value.
      def normalize_payment_fields
        self.processor = processor.presence
        self.accepted_payment_methods = Array(accepted_payment_methods).map { |name| name.to_s.strip }.compact_blank.uniq
      end

      # Nobody could pay for it: it needs an online processor or at least one other way to pay.
      def payable_some_way
        return if amount_cents.to_i.zero?

        errors.add(:base, :no_payment_method) if processor.blank? && accepted_payment_methods.empty?
      end

      # Accepted methods are the ones outside a vendor. They must be installed, and the online
      # processor is chosen in its own field, so it does not belong in this list.
      def accepted_methods_are_not_online_processors
        accepted_payment_methods.each do |name|
          next if name != processor && self.class.local_method?(name)

          errors.add(:accepted_payment_methods, :not_an_offline_method, method: name)
        end
      end
    end
  end
end
