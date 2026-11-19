# frozen_string_literal: true

require 'rails_helper'

# Telling a person that store credit was given to them.
RSpec.describe BetterTogether::Billing::Notifier, 'for store credit' do # rubocop:disable RSpec/SpecFilePathFormat, RSpec/DescribeMethod
  include_context 'with billing notifications'
  include_context 'with store credit fixtures'

  let(:routes) { BetterTogether::Engine.routes.url_helpers }

  def notify(lot, recipient = buyer)
    deliver_now { described_class.with(record: lot, kind: 'credit_granted', audience: :holder).deliver_later([recipient]) }
    inbox(recipient).order(:created_at).last
  end

  before do
    clear_enqueued_jobs
    Noticed::Notification.delete_all
    Noticed::Event.delete_all
    BetterTogether::Billing::NotificationReceipt.delete_all
  end

  it 'says how much, in the holder\'s language, without a date when it does not expire' do
    notification = notify(grant_credit(2500))
    event = notification.event

    expect(event.title).to eq('You have US$25.00 in store credit')
    expect(event.body).to eq("It is yours to spend on what #{host_platform.name} sells.")
  end

  it 'says until when when it expires' do
    lot = grant_credit(2500, expires_at: Time.zone.local(2027, 3, 4))

    expect(notify(lot).event.body).to include('March 04, 2027').or include('March 4, 2027')
  end

  it 'uses the holder\'s own locale' do
    buyer.update!(locale: 'fr')
    notification = notify(grant_credit(2500))

    expect(notification.event.build_message(notification)[:title]).to include('crédit en magasin')
  end

  it 'leads to the holder\'s credit page' do
    expect(notify(grant_credit(2500)).event.url).to eq(routes.billing_credit_path(locale: I18n.locale))
  end

  it 'is sent by Grant to the holder only, once, and never to the steward who gave it' do
    deliver_now { grant_credit(2500, idempotency_key: 'same') }
    deliver_now { grant_credit(2500, idempotency_key: 'same') }

    expect(kinds_for(buyer)).to eq(['credit_granted'])
    expect(kinds_for(steward)).to be_empty
  end

  it 'is not sent for credit the system gives (a refund or promotion has no steward)' do
    deliver_now do
      BetterTogether::Billing::Credit::Grant.call(platform: host_platform, holder: buyer, amount_cents: 500, currency: 'USD', origin: 'refund',
                                                  idempotency_key: 'sys')
    end

    expect(kinds_for(buyer)).to be_empty
  end
end
