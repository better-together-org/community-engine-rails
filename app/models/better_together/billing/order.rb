# frozen_string_literal: true

module BetterTogether
  module Billing
    # What a person is buying, from the platform or one of its sellers, and where it stands.
    #
    # An order is processor-neutral: it has lines (what is bought), payments (how it is being
    # paid, possibly in parts by different methods) and, if money is given back, refunds. Its
    # status is derived from its payments by Orders::Settle, and moves only along the paths in
    # TRANSITIONS, so a paid order cannot quietly become a draft again.
    #
    # Reach orders through their platform (`platform.billing_orders`), never with a bare
    # class-level read. See docs/billing/orders_and_payments.md.
    class Order < ApplicationRecord # rubocop:disable Metrics/ClassLength
      include PlatformBound
      include SellerScoped
      include Subjectable

      self.table_name = 'better_together_billing_orders'

      PURPOSES = ProcessorSetting::PURPOSES
      STATUSES = %w[draft awaiting_payment partially_paid paid cancelled expired partially_refunded refunded].freeze
      # Where an order may go next. A late payment can still pay an expired order (a cheque that
      # arrives after the hold ran out); a cancelled or refunded order is final.
      TRANSITIONS = {
        'draft' => %w[awaiting_payment cancelled],
        'awaiting_payment' => %w[partially_paid paid cancelled expired],
        'partially_paid' => %w[paid expired],
        'expired' => %w[paid partially_paid cancelled],
        'paid' => %w[partially_refunded refunded],
        'partially_refunded' => %w[partially_refunded refunded],
        'cancelled' => [],
        'refunded' => []
      }.freeze
      # An order in one of these is waiting to be paid.
      OPEN_STATUSES = %w[awaiting_payment partially_paid].freeze
      DEFAULT_HOLD_HOURS = 72
      NUMBER_ATTEMPTS = 5

      belongs_to :buyer, class_name: 'BetterTogether::Person', optional: false
      belongs_to :on_behalf_of, polymorphic: true, optional: true
      belongs_to :subject, polymorphic: true, optional: true

      has_many :lines, -> { order(:position, :created_at) }, class_name: 'BetterTogether::Billing::OrderLine',
                                                             inverse_of: :order, dependent: :destroy
      has_many :agreement_acceptances, class_name: 'BetterTogether::Billing::OrderAgreementAcceptance', inverse_of: :order,
                                       dependent: :restrict_with_error
      has_many :payments, class_name: 'BetterTogether::Billing::Payment', inverse_of: :order, dependent: :restrict_with_error

      before_validation :set_number, on: :create
      before_validation :total_up

      validates :purpose, inclusion: { in: PURPOSES }
      validates :status, inclusion: { in: STATUSES }
      validates :currency, inclusion: { in: Plan::SUPPORTED_CURRENCY_CODES }
      validates :number, presence: true, uniqueness: { scope: :platform_id }
      validates :subtotal_cents, :total_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validate :status_transition_allowed, on: :update
      validate :on_behalf_of_allowed
      validate :subject_registered

      STATUSES.each do |status|
        scope status.to_sym, -> { where(status:) }
        define_method(:"#{status}?") { self.status == status }
      end
      scope :unpaid, -> { where(status: OPEN_STATUSES) }
      scope :expired_holds, -> { where(status: OPEN_STATUSES).where(arel_table[:expires_at].lt(Time.current)) }
      scope :bought_by, ->(person) { where(buyer_id: person.id) }
      scope :newest_first, -> { order(created_at: :desc) }

      def open? = OPEN_STATUSES.include?(status)

      def final? = TRANSITIONS.fetch(status).empty?

      def can_become?(new_status) = TRANSITIONS.fetch(status, []).include?(new_status.to_s)

      # Money received: a payment that was later refunded was still paid.
      def paid_cents = payments.select { |payment| %w[succeeded partially_refunded refunded].include?(payment.status) }.sum(&:amount_cents)

      def refunded_cents = payments.sum(&:refunded_cents)

      def balance_cents = [total_cents - paid_cents, 0].max

      def hold_expired? = open? && expires_at.present? && expires_at < Time.current

      private

      # A short reference people can quote, unique per platform. Retried if it collides.
      def set_number
        return if number.present?

        NUMBER_ATTEMPTS.times do
          candidate = "BT-#{SecureRandom.alphanumeric(8).upcase}"
          unless self.class.exists?(platform_id:, number: candidate)
            self.number = candidate
            return
          end
        end
      end

      # Lines decide the totals while there are lines; an order with none keeps what it has.
      def total_up
        return if lines.empty?

        self.subtotal_cents = lines.reject(&:marked_for_destruction?).sum(&:total_cents)
        self.total_cents = subtotal_cents
      end

      def status_transition_allowed
        return unless status_changed?

        was = status_was
        return if status == was || TRANSITIONS.fetch(was, []).include?(status)

        errors.add(:status, :transition_not_allowed, from: was, to: status)
      end

      def on_behalf_of_allowed
        return if on_behalf_of_type.blank? && on_behalf_of_id.blank?
        # Never load an owner whose type is not on the allow-list.
        return errors.add(:on_behalf_of_type, :inclusion) unless SellerScoped.assignable_types.include?(on_behalf_of_type)

        errors.add(:platform, :platform_owner_mismatch) if on_behalf_of_on_another_platform?
      end

      def on_behalf_of_on_another_platform?
        bound = on_behalf_of.try(:billing_bound_platform_id) || on_behalf_of.try(:platform_id)
        bound.present? && platform_id.present? && bound != platform_id
      end

      def subject_registered
        return if subject_type.blank?

        errors.add(:subject_type, :inclusion) if Subjectable.model_names.exclude?(subject_type)
      end
    end
  end
end
