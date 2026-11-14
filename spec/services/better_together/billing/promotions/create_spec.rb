# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Promotions::Create do
  include_context 'with store credit fixtures'

  def make(**attrs)
    described_class.call(platform: host_platform, actor: steward, name: 'Spring drive', amount_cents: 1500, currency: 'USD', **attrs)
  end

  it 'makes a promotion and its code, shown once' do
    result = make(credit_expires_after_days: 30, max_redemptions: 50, purposes: %w[one_time], new_members_only: true)

    expect(result.code).to match(/\A([A-Z2-9]{4}-){3}[A-Z2-9]{4}\z/)
    expect(result.promotion).to have_attributes(name: 'Spring drive', amount_cents: 1500, currency: 'USD', created_by: steward, active: true,
                                                credit_expires_after_days: 30, max_redemptions: 50, purposes: %w[one_time],
                                                new_members_only: true, redemptions_count: 0, platform_id: host_platform.id)
  end

  it 'keeps only a keyed digest of the code, never the code' do
    result = make
    digest = result.promotion.code_digest

    expect(digest).to match(/\A\h{64}\z/)
    expect(digest).to eq(BetterTogether::Billing::Promotion.digest_for(result.code))
    columns = result.promotion.attributes.values.compact.map(&:to_s)
    expect(columns.grep(/#{Regexp.escape(result.code.delete('-'))}/i)).to be_empty
    expect(result.promotion.reload.attributes.keys).not_to include('code')
  end

  it 'makes a different code every time' do
    codes = Array.new(5) { make.code }

    expect(codes.uniq.size).to eq(5)
  end

  it 'tries again when a code collides with another' do
    first = make
    allow(BetterTogether::Billing::Promotion).to receive(:generate_code).and_return(first.code, 'ABCD-EFGH-JKMN-PQRS')

    expect(make.code).to eq('ABCD-EFGH-JKMN-PQRS')
  end

  it 'refuses what makes no sense' do
    [{ amount_cents: 0 }, { name: '' }, { currency: 'XXX' }, { max_redemptions: 0 }, { credit_expires_after_days: -1 },
     { starts_at: 2.days.from_now, ends_at: 1.day.from_now }, { purposes: %w[bribes] }].each do |bad|
      expect { make(**bad) }.to raise_error(described_class::Refused)
    end
  end

  it 'ignores options it does not know' do
    expect(make(code_digest: 'x', redemptions_count: 99).promotion).to have_attributes(redemptions_count: 0)
  end
end
