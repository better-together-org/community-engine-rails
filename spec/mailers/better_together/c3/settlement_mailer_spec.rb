# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::C3::SettlementMailer do
  let(:recipient) { Struct.new(:email, :locale, :time_zone).new('recipient@example.test', :en, 'UTC') }
  let(:agreement) { Struct.new(:to_param).new('1') }
  let(:settlement) { Struct.new(:c3_millitokens, :agreement).new(12_500, agreement) }

  before do
    allow(BetterTogether::Engine.routes.url_helpers).to receive(:joatu_agreement_url)
      .with(agreement, locale: :en)
      .and_return('https://example.test/en/exchange/agreements/1')
  end

  it 'renders a settlement notification email' do
    mail = described_class.with(
      recipient: recipient,
      settlement: settlement,
      event_type: :c3_settled
    ).settlement_notification

    expect(mail.to).to eq(['recipient@example.test'])
    expect(mail.subject).to include('Tree Seeds')
    expect(mail.body.encoded).to include('1.25 Tree Seeds')
    expect(mail.body.encoded).to include('View agreement')
  end
end
