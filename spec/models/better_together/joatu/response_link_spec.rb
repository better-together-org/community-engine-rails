# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::ResponseLink do
  let(:offer) { create(:better_together_joatu_offer) }
  let(:request) { create(:better_together_joatu_request) }

  it 'prevents creating a response link for a closed source' do
    offer.update!(status: 'closed')
    rl = described_class.new(source: offer, response: request)
    expect(rl).not_to be_valid
    expect(rl.errors[:source]).to include('must be open or matched to create a response')
  end

  it 'marks open source as matched on create' do
    offer.update!(status: 'open')
    described_class.create!(source: offer, response: request, creator_id: create(:person).id)
    expect(offer.reload.status).to eq('matched')
  end

  describe 'match notifications and blocks' do
    let(:match_events) { Noticed::Event.where(type: 'BetterTogether::Joatu::MatchNotifier') }

    it 'notifies the source creator when no block exists' do
      expect do
        described_class.create!(source: offer, response: request, creator_id: create(:person).id)
      end.to change(match_events, :count).by(1)
    end

    it 'does not notify when the creators have a block between them' do
      create(:person_block, blocker: request.creator, blocked: offer.creator)

      expect do
        described_class.create!(source: offer, response: request, creator_id: create(:person).id)
      end.not_to(change(match_events, :count))
    end
  end
end
