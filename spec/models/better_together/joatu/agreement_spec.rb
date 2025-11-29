# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::Agreement do
  let(:creator_a) { create(:better_together_person) }
  let(:creator_b) { create(:better_together_person) }
  let(:offer)     { create(:better_together_joatu_offer, creator: creator_a) }
  let(:request)   { create(:better_together_joatu_request, creator: creator_b) }

  describe 'status transitions' do
    it 'starts pending' do # rubocop:todo RSpec/MultipleExpectations
      agreement = described_class.new(offer:, request:)
      expect(agreement).to be_valid
      expect(agreement.status).to eq('pending')
    end

    it 'prevents changing from accepted to pending' do # rubocop:todo RSpec/MultipleExpectations
      agreement = create(:better_together_joatu_agreement, offer:, request:)
      agreement.update!(status: 'accepted')
      agreement.status = 'pending'
      expect(agreement).not_to be_valid
      expect(agreement.errors[:status]).to be_present
    end

    it 'prevents accepting when either side is already closed' do
      agreement = create(:better_together_joatu_agreement, offer:, request:)
      offer.status_closed!
      expect { agreement.accept! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'prevents rejecting when either side is already closed' do
      agreement = create(:better_together_joatu_agreement, offer:, request:)
      request.status_closed!
      expect { agreement.reject! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    # rubocop:todo RSpec/MultipleExpectations
    it 'prevents rejecting after accepted or already rejected' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      agreement = create(:better_together_joatu_agreement, offer:, request:)
      agreement.accept!
      expect { agreement.reject! }.to raise_error(ActiveRecord::RecordInvalid)

      agreement2 = create(:better_together_joatu_agreement, offer: create(:better_together_joatu_offer),
                                                            request: create(:better_together_joatu_request))
      agreement2.reject!
      expect { agreement2.reject! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    # rubocop:todo RSpec/MultipleExpectations
    it 'enforces only one accepted agreement per offer and per request' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      offer2   = create(:better_together_joatu_offer, creator: creator_a)
      request2 = create(:better_together_joatu_request, creator: creator_b)

      ag1 = create(:better_together_joatu_agreement, offer:, request:)
      ag2 = create(:better_together_joatu_agreement, offer:, request: request2)
      ag3 = create(:better_together_joatu_agreement, offer: offer2, request:)

      ag1.accept!

      # Same offer cannot accept another agreement
      expect { ag2.accept! }.to raise_error(ActiveRecord::RecordInvalid)

      # Same request cannot accept another agreement
      expect { ag3.accept! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
