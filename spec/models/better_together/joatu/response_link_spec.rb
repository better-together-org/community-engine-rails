# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::ResponseLink do
  let(:offer) { create(:better_together_joatu_offer) }
  let(:request) { create(:better_together_joatu_request) }

  it 'prevents creating a response link for a closed source' do # rubocop:todo RSpec/MultipleExpectations
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
end
