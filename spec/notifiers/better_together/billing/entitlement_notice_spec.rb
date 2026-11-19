# frozen_string_literal: true

require 'rails_helper'

# What payers are told when what a plan gives starts and stops.
RSpec.describe BetterTogether::Billing::Notifier, 'for entitlements' do # rubocop:disable RSpec/SpecFilePathFormat, RSpec/DescribeMethod
  include_context 'with entitlement fixtures'

  let(:routes) { BetterTogether::Engine.routes.url_helpers }
  let(:entitlement) { make_entitlement }

  def notify(kind)
    entitlement
    clear_notices
    deliver_now { described_class.with(record: entitlement, kind:, audience: :buyer).deliver_later([entitlement.payer]) }
    inbox(entitlement.payer).order(:created_at).last
  end

  it 'says the plan is active, and leads to My access' do
    event = notify('entitlement_granted').event

    expect(event.title).to eq("Your #{sub_plan.name} access is active")
    expect(event.url).to eq(routes.billing_entitlements_path(locale: I18n.locale))
  end

  it 'says access ended and that nothing was deleted' do
    entitlement.update!(status: 'lapsed')

    expect(notify('entitlement_lapsed').event.body).to include('nothing you made was deleted')
  end

  it 'is told in the payer\'s language' do
    entitlement.payer.update!(locale: 'fr')
    notification = notify('entitlement_granted')

    expect(notification.event.build_message(notification)[:title]).to include('accès')
  end

  it 'goes to the person who paid, not to who it is for' do
    recipients = BetterTogether::Billing::Notifications::Recipients.call(audience: :buyer, subject: entitlement)

    expect(recipients).to eq([entitlement.payer])
  end

  it 'is not critical' do
    expect(described_class.new(params: { kind: 'entitlement_lapsed', audience: :buyer })).not_to be_critical
  end
end
