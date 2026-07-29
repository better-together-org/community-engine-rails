# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Borgberry::Decorations::JoatuAgreement' do
  let(:creator_a) { create(:better_together_person) }
  let(:creator_b) { create(:better_together_person) }
  let(:request) { create(:better_together_joatu_request, creator: creator_b) }

  it 'cancels an accepted C3-priced agreement, releases the lock, and reopens both sides' do
    priced_offer = create(:better_together_joatu_offer, creator: creator_a, c3_price_millitokens: 20_000)
    agreement = create(:better_together_joatu_agreement, offer: priced_offer, request:)
    payer_balance = BetterTogether::C3::Balance.find_or_create_by!(holder: creator_b)
    # credit! takes Tree Seeds (not millitokens); must cover the 20_000-millitoken
    # (20 Tree Seed) offer price, so credit comfortably above that amount.
    payer_balance.credit!(25.0)

    agreement.accept!

    settlement = agreement.reload.settlement
    lock = BetterTogether::C3::BalanceLock.find_by!(lock_ref: settlement.lock_ref)

    agreement.cancel!

    expect(agreement.reload.status).to eq('cancelled')
    expect(settlement.reload.status).to eq('cancelled')
    expect(lock.reload.status).to eq('released')
    expect(priced_offer.reload.status).to eq('open')
    expect(request.reload.status).to eq('open')
    expect(agreement.decision_made_at).to be_present
  end
end
