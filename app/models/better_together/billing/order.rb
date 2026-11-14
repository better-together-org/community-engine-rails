# frozen_string_literal: true

module BetterTogether
  module Billing
    # What a person is buying, from the platform or one of its sellers, and where it stands.
    #
    # An order is processor-neutral: it has line items (what is bought), payments (how it is being
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
      include EncryptedAttributes

      self.table_name = 'better_together_billing_orders'

      PURPOSES = ProcessorSetting::PURPOSES
      STATUSES = %w[draft awaiting_payment partially_paid paid cancelled expired partially_refunded refunded].freeze
      # Where an order may go next. A late payment can still pay an expired order (a cheque that
      # arrives after the hold ran out); a cancelled or refunded order is final.
      TRANSITIONS = {
        'draft' => %w[awaiting_payment cancelled],
        'awaiting_payment' => %w[partially_paid paid cancelled expired],
        # Partly paid is an ordinary state. It never lapses on its own (money is against it); if the paid parts are
        # returned it goes back to waiting for payment, and a steward may cancel it once nothing is left against it.
        'partially_paid' => %w[paid awaiting_payment cancelled],
        'expired' => %w[paid partially_paid cancelled],
        'paid' => %w[partially_refunded refunded],
        # A refund can fail after it was recorded, which puts the order back where it was.
        'partially_refunded' => %w[paid partially_refunded refunded],
        'refunded' => %w[paid partially_refunded],
        'cancelled' => []
      }.freeze
      # An order in one of these is waiting to be paid.
      OPEN_STATUSES = %w[awaiting_payment partially_paid].freeze
      DEFAULT_HOLD_HOURS = 72
      NUMBER_ATTEMPTS = 5

      belongs_to :buyer, class_name: 'BetterTogether::Person', optional: false
      belongs_to :on_behalf_of, polymorphic: true, optional: true
      belongs_to :subject, polymorphic: true, optional: true
      # The Pay subscription this order is the first payment of, for a processor-backed plan.
      belongs_to :pay_subscription, class_name: 'Pay::Subscription', optional: true

      has_many :line_items, -> { order(:position, :created_at) }, class_name: 'BetterTogether::Billing::LineItem',
                                                                  inverse_of: :order, dependent: :destroy
      has_many :tax_lines, class_name: 'BetterTogether::Billing::TaxLine', inverse_of: :order, dependent: :destroy
      # The registration whose tax this order carries, if any.
      belongs_to :tax_registration, class_name: 'BetterTogether::Billing::TaxRegistration', optional: true
      # The settlement the tax was worked out for, when the buyer's place was a city or town.
      belongs_to :tax_settlement, class_name: 'BetterTogether::Geography::Settlement', optional: true
      # Where the billing address snapshot came from. The snapshot (`billing_address`) is what the order keeps; this is cleared if the
      # address is deleted.
      belongs_to :billing_address_source, class_name: 'BetterTogether::Address', foreign_key: :billing_address_id, optional: true,
                                          inverse_of: false
      has_many :agreement_acceptances, class_name: 'BetterTogether::Billing::OrderAgreementAcceptance', inverse_of: :order,
                                       dependent: :restrict_with_error
      has_many :documents, class_name: 'BetterTogether::Billing::OrderDocument', inverse_of: :order, dependent: :destroy
      has_many :payments, class_name: 'BetterTogether::Billing::Payment', inverse_of: :order, dependent: :restrict_with_error
      has_many :refund_requests, class_name: 'BetterTogether::Billing::RefundRequest', inverse_of: :order, dependent: :restrict_with_error
      has_many :offline_payments, class_name: 'BetterTogether::Billing::OfflinePayment', inverse_of: :order,
                                  dependent: :restrict_with_error

      # Where billing notices for this order go, and the billing address given at the sale. Personal data, so encrypted.
      encrypts_billing_attribute :buyer_email
      encrypts_billing_attribute :billing_address, json: true

      before_validation :set_number, on: :create
      before_validation :remember_placed_locale, on: :create
      before_validation :total_up

      validates :purpose, inclusion: { in: PURPOSES }
      validates :buyer_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
      validates :document_locale, inclusion: { in: ->(_order) { I18n.available_locales.map(&:to_s) } }, allow_nil: true
      validates :status, inclusion: { in: STATUSES }
      validates :currency, inclusion: { in: Plan::SUPPORTED_CURRENCY_CODES }
      validates :number, presence: true, uniqueness: { scope: :platform_id }
      validates :subtotal_cents, :total_cents, :tax_cents, :included_tax_cents,
                numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validate :status_transition_allowed, on: :update
      validate :on_behalf_of_allowed
      validate :pay_subscription_on_this_platform
      validate :subject_registered

      STATUSES.each do |status|
        scope status.to_sym, -> { where(status:) }
        define_method(:"#{status}?") { self.status == status }
      end
      scope :unpaid, -> { where(status: OPEN_STATUSES) }
      scope :expired_holds, -> { where(status: OPEN_STATUSES).where(arel_table[:expires_at].lt(Time.current)) }
      scope :bought_by, ->(person) { where(buyer_id: person.id) }
      scope :newest_first, -> { order(created_at: :desc) }
      scope :with_status, ->(status) { where(status:) }
      scope :created_in_year, lambda { |year|
        start = Time.utc(year.to_i, 1, 1)
        where(created_at: start...start.next_year)
      }

      # The invoice or receipt PDF that is current, if one has been made.
      def invoice_document = documents.current.of_kind(:invoice).first

      def receipt_document = documents.current.of_kind(:receipt).first

      def open? = OPEN_STATUSES.include?(status)

      def final? = TRANSITIONS.fetch(status).empty?

      def can_become?(new_status) = TRANSITIONS.fetch(status, []).include?(new_status.to_s)

      # Money received: a payment that was later refunded was still paid.
      def paid_cents = payments.select { |payment| %w[succeeded partially_refunded refunded].include?(payment.status) }.sum(&:amount_cents)

      def refunded_cents = payments.sum(&:refunded_cents)

      # What is still against the order: paid, less what was given back. This is what decides whether it is paid,
      # partly paid, or waiting.
      def net_paid_cents = paid_cents - refunded_cents

      # What is still to pay. Money given back is owed again, so a part that was returned can be paid another way.
      def balance_cents = [total_cents - net_paid_cents, 0].max

      # Some of it is paid and some is not: a normal state, not a problem.
      def partly_paid? = open? && net_paid_cents.positive?

      # The tax that comes on top of the line items.
      def added_tax_cents = tax_cents.to_i - included_tax_cents.to_i

      def hold_expired? = open? && expires_at.present? && expires_at < Time.current

      # The language the stored invoice and receipt were written in, which stays the same when the buyer's own language
      # changes later. Until any has been made it is the language they would be made in.
      def documents_locale
        documents.current.where.not(locale: nil).order(:generated_at).pick(:locale) || locale_for_documents.to_s
      end

      # The language this order's invoice and receipt are made in: the one a steward chose for it, else the buyer's, else
      # the one it was placed in, else the platform's. A steward who placed it for someone who does not read that language
      # chooses another (see Orders::GenerateDocument and the order's documents).
      def locale_for_documents
        known = I18n.available_locales.map(&:to_s)
        [document_locale, buyer&.locale, placed_locale, Billing.platform_locale(platform)].map(&:to_s).find do |code|
          known.include?(code)
        end.to_sym
      end

      private

      # A short reference people can quote, unique per platform. Retried if it collides.
      def remember_placed_locale = self.placed_locale ||= I18n.locale.to_s

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

      # Line items decide the totals while there are line items; an order with none keeps what it has. Tax that is
      # added to the prices is part of the total; tax that is already inside the prices is not added again.
      def total_up
        return if line_items.empty?

        self.subtotal_cents = line_items.reject(&:marked_for_destruction?).sum(&:total_cents)
        self.total_cents = subtotal_cents + added_tax_cents
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

      def pay_subscription_on_this_platform
        return if pay_subscription.blank? || pay_subscription.platform_id == platform_id

        errors.add(:pay_subscription, :platform_owner_mismatch)
      end

      def subject_registered
        return if subject_type.blank?

        errors.add(:subject_type, :inclusion) if Subjectable.model_names.exclude?(subject_type)
      end
    end
  end
end
