# frozen_string_literal: true

require 'rails_helper'

# What payers and stewards are told about renewals.
RSpec.describe BetterTogether::Billing::Notifier, 'for subscriptions' do # rubocop:disable RSpec/SpecFilePathFormat, RSpec/DescribeMethod
  include_context 'with subscription fixtures'

  let(:term) { start_subscription }
  let(:routes) { BetterTogether::Engine.routes.url_helpers }
  let(:period) { generate_renewal(term, at: Time.utc(2027, 2, 20)) }

  def notify(kind, subject, recipient: buyer, audience: :buyer)
    clear_notices
    deliver_now { described_class.with(record: subject, kind:, audience:).deliver_later([recipient]) }
    inbox(recipient).order(:created_at).last
  end

  it 'says what the invoice is for, how much, and until when the current period runs' do
    event = notify('renewal_invoice_issued', period).event

    expect(event.title).to eq("Renewal invoice #{period.order.number}")
    expect(event.body).to include(sub_plan.name, 'US$30.00', 'February 28, 2027')
  end

  it 'says when the extra time ends for an overdue renewal, to the payer and to a steward' do
    advance(term, at: Time.utc(2027, 3, 1))
    clear_notices

    expect(notify('renewal_overdue', period).event.body).to include('March 07, 2027').or include('March 7, 2027')
    expect(notify('renewal_overdue', period, recipient: steward, audience: :seller).event.title).to include(sub_plan.name)
  end

  it 'names the price for a notice that has no invoice yet' do
    change_subscription_agreement
    waiting = generate_renewal(term, at: Time.utc(2027, 2, 20))

    expect(notify('agreement_reacceptance_needed', waiting).event.body).to include(sub_plan.name)
  end

  it 'leads the payer to their subscription and a steward to the subscriber' do
    expect(notify('renewal_reminder', period).event.url).to eq(routes.billing_subscription_path(term, locale: I18n.locale))
    expect(notify('renewal_overdue', period, recipient: steward, audience: :seller).event.url)
      .to eq(routes.billing_subscriber_path(term, locale: I18n.locale))
  end

  it 'is told in the payer\'s language' do
    buyer.update!(locale: 'fr')
    notification = notify('renewal_invoice_issued', period)

    expect(notification.event.build_message(notification)[:title]).to include('Facture de renouvellement')
  end

  it 'is critical only for an overdue renewal and the end of the grace' do
    expect(described_class.new(params: { kind: 'renewal_overdue', audience: :buyer })).to be_critical
    expect(described_class.new(params: { kind: 'grace_ending', audience: :buyer })).to be_critical
    expect(described_class.new(params: { kind: 'renewal_reminder', audience: :buyer })).not_to be_critical
  end

  it 'reaches the payer of a subscription for someone else, not the one it is for' do
    other = create(:better_together_person)
    paid_for = start_subscription(on_behalf_of: other, payer: create(:better_together_person))

    expect(BetterTogether::Billing::Notifications::Recipients.call(audience: :buyer, subject: paid_for)).to eq([paid_for.payer])
  end
end
