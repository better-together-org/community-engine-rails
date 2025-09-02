# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::Matchmaker do
  let(:creator_a) { create(:better_together_person) }
  let(:creator_b) { create(:better_together_person) }
  let(:category)  { create(:better_together_joatu_category) }

  def with_category(record)
    record.categories << category unless record.categories.include?(category)
    record
  end

  describe '.match' do
    context 'pair-specific response link exclusion' do # rubocop:todo RSpec/ContextWording
      # rubocop:todo RSpec/ExampleLength
      # rubocop:todo RSpec/MultipleExpectations
      it 'excludes an offer only when a response link exists for that specific request->offer pair' do
        # rubocop:enable RSpec/MultipleExpectations
        request = with_category(create(:better_together_joatu_request, creator: creator_a, status: 'open'))
        offer1  = with_category(create(:better_together_joatu_offer, creator: creator_b, status: 'open'))
        offer2  = with_category(create(:better_together_joatu_offer, creator: creator_b, status: 'open'))

        # Pair-specific response link: request -> offer1
        BetterTogether::Joatu::ResponseLink.create!(
          source: request,
          response: offer1,
          creator: creator_a
        )

        matches = described_class.match(request).to_a

        expect(matches).not_to include(offer1)
        expect(matches).to include(offer2)
      end
      # rubocop:enable RSpec/ExampleLength

      it 'does not exclude an offer just because a different request linked to it' do # rubocop:todo RSpec/ExampleLength
        request = with_category(create(:better_together_joatu_request, creator: creator_a, status: 'open'))
        other_request = with_category(create(:better_together_joatu_request, creator: creator_b, status: 'open'))
        offer = with_category(create(:better_together_joatu_offer, creator: creator_b, status: 'open'))

        # A different request created a response link to this offer (does not change offer status)
        BetterTogether::Joatu::ResponseLink.create!(source: other_request, response: offer, creator: creator_b)

        matches = described_class.match(request).to_a
        expect(matches).to include(offer)
      end
    end

    context 'target wildcard behavior' do # rubocop:todo RSpec/ContextWording
      let(:target_person) { create(:better_together_person) }

      it 'matches when request has target_id and offer has nil (wildcard)' do
        request = with_category(create(:better_together_joatu_request, creator: creator_a, status: 'open',
                                                                       target: target_person))
        offer   = with_category(create(:better_together_joatu_offer,   creator: creator_b, status: 'open',
                                                                       # rubocop:todo Layout/LineLength
                                                                       target_type: request.target_type, target_id: nil))
        # rubocop:enable Layout/LineLength

        expect(described_class.match(request)).to include(offer)
      end

      it 'matches when offer has target_id and request has nil (wildcard)' do
        offer   = with_category(create(:better_together_joatu_offer,   creator: creator_b, status: 'open',
                                                                       target: target_person))
        request = with_category(create(:better_together_joatu_request, creator: creator_a, status: 'open',
                                                                       target_type: offer.target_type, target_id: nil))

        expect(described_class.match(offer)).to include(request)
      end

      it 'does not match when both have different non-nil target_id values' do # rubocop:todo RSpec/ExampleLength
        request = with_category(create(:better_together_joatu_request, creator: creator_a, status: 'open',
                                                                       target: target_person))
        other   = create(:better_together_person)
        offer   = with_category(create(:better_together_joatu_offer, creator: creator_b, status: 'open',
                                                                     target: other))

        expect(described_class.match(request)).not_to include(offer)
      end
    end
  end
end
