# frozen_string_literal: true

module BetterTogether
  module Billing
    module Subscriptions
      # Makes the invoice for a subscription's next period, ahead of time (the plan's `renewal_lead_days`).
      #
      # The period row is made first, unique per subscription and sequence, and only then the order that
      # invoices it, so running this twice, or twice at once, makes one period and one invoice. The order is
      # an ordinary order (its number is the invoice number), placed for the payer with the price the
      # subscriber was sold at, held until the period ends plus the grace.
      #
      # If the purchase agreements changed since the payer accepted them, no invoice can be made until they
      # accept again: the period waits as `needs_agreement` and the payer is told. Any other refusal (the
      # method was switched off) leaves it `blocked`. Both are tried again on every run.
      class GenerateRenewal
        def self.call(...) = new(...).call

        def initialize(term:, now: Time.current)
          @term = term
          @now = now
        end

        # The period worked on, or nil when nothing is due.
        def call
          term.with_lock do
            next unless renewable?

            period = pending_period || next_period
            issue(period) if period && period.order.nil?
            period
          end
        end

        private

        attr_reader :term, :now

        def subscription = term.pay_subscription
        def plan = term.plan
        def platform = term.platform

        # Only a subscription that is running and not ending.
        def renewable?
          term.local? && %w[active past_due].include?(subscription.status) && subscription.ends_at.blank?
        end

        def pending_period = term.periods.unsettled.last

        def next_period
          sequence = (term.periods.last&.sequence || -1) + 1
          return unless due?(sequence)

          ChangePlan.apply(term) if term.pending_plan_id
          term.periods.create!(period_attributes(sequence))
        end

        def due?(sequence) = now >= term.period_start(sequence) - plan.renewal_lead_days.days

        def period_attributes(sequence)
          { platform_id: platform.id, sequence:, starts_at: term.period_start(sequence), ends_at: term.period_end(sequence) }
        end

        def issue(period)
          order = place(period)
          period.update!(order:, status: 'pending', blocked_reason: nil)
          Notifications.deliver('renewal_invoice_issued', subject: period)
          PayWithCredit.call(period: period.reload) if Billing.internal_method?(term.payment_method)
        rescue Orders::Place::AgreementsRequired
          period.update!(status: 'needs_agreement', blocked_reason: nil)
          Notifications.deliver('agreement_reacceptance_needed', subject: period, dedupe_key: "reaccept:#{period.id}:#{Date.current}")
        rescue Orders::Place::Refused => e
          period.update!(status: 'blocked', blocked_reason: e.message.to_s.truncate(250))
        end

        def place(period)
          Orders::Place.call(**invoice_attributes, expires_at: [period.ends_at + plan.grace_days.days, now + 1.day].max)
        end

        def invoice_attributes
          { platform:, buyer: term.payer, signer: term.payer, purpose: 'subscription', subject: term, on_behalf_of: term.beneficiary,
            renewal: true, payment_method: method_to_open, line_items: [invoice_line_item], tax_address: }
        end

        # A renewal is taxed through the same calculator as any order, for the place the subscriber was last taxed for:
        # the latest invoice's, else the order that started the subscription. Rates and registrations are read now.
        def tax_address
          source = last_invoice || starting_order
          return {} unless source

          settlement = source.tax_settlement
          return { settlement: } if settlement

          { country_iso: source.tax_country_iso.presence, region_code: source.tax_region_code.presence }.compact
        end

        def last_invoice = term.periods.where.not(order_id: nil).last&.order

        def starting_order
          id = subscription.metadata.to_h['bt_order_id'] if subscription.respond_to?(:metadata)
          platform.billing_orders.find_by(id:) if id
        end

        # Store credit is paid straight after the order is placed, so no payment is opened for it here.
        def method_to_open = (term.payment_method unless Billing.internal_method?(term.payment_method))

        def invoice_line_item = { purchasable: plan, quantity: 1, unit_amount_cents: term.unit_amount_cents }
      end
    end
  end
end
