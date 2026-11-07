# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Promotions::Redeem do
  include_context 'with store credit fixtures'

  let(:invalid) { described_class::Invalid }
  let(:created) { BetterTogether::Billing::Promotions::Create.call(platform: host_platform, actor: steward, name: 'Spring', amount_cents: 1500, currency: 'USD') }
  let(:promotion) { created.promotion }
  let(:code) { created.code }
  let(:person) { create(:better_together_person) }
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

  before { allow(Rails).to receive(:cache).and_return(memory_cache) }

  def redeem(with: code, by: person, **) = described_class.call(platform: host_platform, person: by, code: with, **)

  def make(**attrs)
    BetterTogether::Billing::Promotions::Create.call(platform: host_platform, actor: steward, name: 'P', amount_cents: 1000, currency: 'USD',
                                                     **attrs)
  end

  it 'turns a code into store credit, as a promotional lot' do
    lot = redeem

    expect(lot).to have_attributes(origin: 'promotion', promotional: true, amount_cents: 1500, remaining_cents: 1500, note: 'Spring')
    expect(lot.account).to have_attributes(holder: person, currency: 'USD', balance_cents: 1500)
    expect(promotion.reload.redemptions_count).to eq(1)
    expect(promotion.redemptions.sole).to have_attributes(person:, credit_lot: lot, platform_id: host_platform.id)
  end

  it 'accepts the code however it is typed' do
    expect(redeem(with: " #{code.downcase.delete('-')} ")).to be_present
  end

  it 'makes credit that expires after the days the promotion says, and only pays for what it names' do
    lot = redeem(with: make(credit_expires_after_days: 14, purposes: %w[ticket]).code)

    expect(lot.expires_at).to be_within(1.minute).of(14.days.from_now)
    expect(lot.purposes).to eq(%w[ticket])
  end

  it 'makes credit that does not expire when the promotion has no days' do
    expect(redeem.expires_at).to be_nil
  end

  it 'gives the same answer to every failure, so nobody learns which codes exist' do
    expired = make(starts_at: 3.days.ago, ends_at: 1.day.ago).code
    future = make(starts_at: 1.day.from_now).code
    off = make.tap { |made| made.promotion.update!(active: false) }.code
    used_up = make(max_redemptions: 1).tap { |made| redeem(with: made.code, by: create(:better_together_person)) }.code
    redeem
    answers = ['NOPE-NOPE-NOPE-NOPE', expired, future, off, used_up, code, 'x', '', nil].map do |attempt|
      redeem(with: attempt)
    rescue invalid => e
      e.message
    end

    expect(answers.uniq).to eq(['that code is not valid'])
  end

  it 'leaves no credit behind when it fails' do
    expect { redeem(with: 'NOPE-NOPE-NOPE-NOPE') }.to raise_error(invalid)

    expect(host_platform.billing_credit_accounts.where(holder: person)).to be_empty
  end

  it 'lets a person use a code once' do
    redeem

    expect { redeem }.to raise_error(invalid)
    expect(promotion.reload.redemptions_count).to eq(1)
    expect(promotion.redemptions.count).to eq(1)
  end

  it 'stops at the most people the promotion allows, however many ask' do
    capped = make(max_redemptions: 2).code
    people = Array.new(4) { create(:better_together_person) }

    results = people.map do |each_person|
      redeem(with: capped, by: each_person)
      :redeemed
    rescue invalid
      :refused
    end

    expect(results.tally).to eq(redeemed: 2, refused: 2)
  end

  it 'opens and closes on the dates given' do
    window = make(starts_at: 1.day.from_now, ends_at: 3.days.from_now).code

    expect { redeem(with: window) }.to raise_error(invalid)
    expect(redeem(with: window, now: 2.days.from_now)).to be_present
    expect { redeem(with: window, by: create(:better_together_person), now: 4.days.from_now) }.to raise_error(invalid)
  end

  it 'can be for new members only: people who have not paid for anything on the platform' do
    code = make(new_members_only: true).code
    grant_credit(5000, holder: person)
    paid = place_order(buyer: person)
    paid.update_columns(paid_at: Time.current, status: 'paid') # rubocop:disable Rails/SkipsModelValidations

    expect { redeem(with: code) }.to raise_error(invalid)
    expect(redeem(with: code, by: create(:better_together_person))).to be_present
  end

  it 'does not find a code that belongs to another platform' do
    other = create(:better_together_platform)
    foreign = BetterTogether::Billing::Promotions::Create.call(platform: other, actor: steward, name: 'X', amount_cents: 500, currency: 'USD')

    expect { redeem(with: foreign.code) }.to raise_error(invalid)
  end

  it 'refuses a person outright after too many failures, even for a good code, until the hour passes' do
    described_class::MAX_FAILURES.times { expect { redeem(with: 'NOPE-NOPE-NOPE-NOPE') }.to raise_error(invalid) }

    expect { redeem }.to raise_error(invalid)
    expect(promotion.reload.redemptions_count).to eq(0)
    memory_cache.clear
    expect(redeem).to be_present
  end

  it 'counts failures per person, so one person cannot lock out another' do
    described_class::MAX_FAILURES.times { expect { redeem(with: 'NOPE-NOPE-NOPE-NOPE') }.to raise_error(invalid) }

    expect(redeem(by: create(:better_together_person))).to be_present
  end

  it 'does not look the code up at all when it cannot be the right length' do
    allow(BetterTogether::Billing::Promotion).to receive(:digest_for).and_call_original

    expect { redeem(with: 'short') }.to raise_error(invalid)
    expect(BetterTogether::Billing::Promotion).not_to have_received(:digest_for)
  end

  it 'never puts the code in an error, a log line or a credit record' do
    lot = redeem

    expect([lot.note, lot.account.entries.map(&:note)].flatten.join(' ')).not_to include(code)
    expect { redeem }.to raise_error(invalid) { |error| expect(error.message).not_to include(code) }
  end
end
