# frozen_string_literal: true

# Builds paid orders, with lines, taxes, payments and refunds, straight into the tables the billing report reads.
# `paid_order` returns the order; `taxed_line` and `refund_for` add to it.
RSpec.shared_context 'with billing report data' do
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:report_plan) { create(:better_together_billing_plan, platform: host_platform) }

  # Orders are given their totals up front; a line says its price (with the tax inside it when `included`).
  def paid_order( # rubocop:disable Metrics/ParameterLists
    paid_at:, currency: 'CAD', seller: nil, status: 'paid', platform: host_platform, **attrs
  )
    create(:better_together_billing_order, platform:, currency:, status:, paid_at:, placed_at: paid_at, seller:, **attrs)
  end

  def line_for(order, # rubocop:disable Metrics/AbcSize
               cents:, category: nil, taxes: [], included: false)
    tax_total = taxes.sum { |_label, _rate, amount| amount }
    line = create(:better_together_billing_line_item, order:, unit_amount_cents: cents, currency: order.currency, tax_category: category,
                                                      purchasable: create(:better_together_billing_plan, platform: order.platform),
                                                      tax_cents: tax_total, included_tax_cents: included ? tax_total : 0)
    taxes.each do |label, rate, amount|
      create(:better_together_billing_tax_line, order:, line_item: line, label:, rate:, amount_cents: amount, included:,
                                                platform: order.platform)
    end
    order.update_columns(subtotal_cents: order.subtotal_cents + cents, tax_cents: order.tax_cents + tax_total, # rubocop:disable Rails/SkipsModelValidations
                         included_tax_cents: order.included_tax_cents + (included ? tax_total : 0),
                         total_cents: order.total_cents + cents + (included ? 0 : tax_total))
    line
  end

  def pay(order, processor: 'cash', amount: nil)
    create(:better_together_billing_payment, order:, platform_id: order.platform_id, processor:, status: 'succeeded',
                                             amount_cents: amount || order.reload.total_cents, currency: order.currency, paid_at: order.paid_at)
  end

  def refund_for(payment, amount:, tax:, at:, status: 'recorded')
    create(:better_together_billing_refund, payment:, platform_id: payment.platform_id, amount_cents: amount, tax_cents: tax, status:,
                                            created_at: at, currency: payment.currency)
  end
end
