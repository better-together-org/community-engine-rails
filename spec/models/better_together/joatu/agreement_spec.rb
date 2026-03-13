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

    it 'creates or activates a platform connection when accepting a connection request agreement' do
      source_platform = create(:better_together_platform)
      target_platform = create(:better_together_platform)
      connection_offer = create(:better_together_joatu_offer, creator: creator_a, target: source_platform)
      connection_request = create(:better_together_joatu_connection_request, creator: creator_b, target: target_platform)
      agreement = create(:better_together_joatu_agreement, offer: connection_offer, request: connection_request)

      expect { agreement.accept! }
        .to change(BetterTogether::PlatformConnection.active, :count).by(1)

      connection = BetterTogether::PlatformConnection.find_by(source_platform:, target_platform:)
      expect(connection).to be_present
      expect(connection).to be_active
    end

    it 'creates a person link when accepting a person link request agreement' do
      source_platform = create(:better_together_platform)
      target_platform = create(:better_together_platform)
      create(:better_together_platform_connection, :active, source_platform:, target_platform:)
      source_person = create(:better_together_person)
      target_person = create(:better_together_person)

      source_platform.person_platform_memberships.create!(member: source_person, role: create(:better_together_role), status: 'active')
      target_platform.person_platform_memberships.create!(member: target_person, role: create(:better_together_role), status: 'active')

      link_offer = create(:better_together_joatu_offer, creator: source_person, target: source_person)
      link_request = create(:better_together_joatu_person_link_request, creator: target_person, target: target_person)
      agreement = create(:better_together_joatu_agreement, offer: link_offer, request: link_request)

      expect { agreement.accept! }.to change(BetterTogether::PersonLink.active, :count).by(1)
    end

    it 'creates a fail-closed person access grant when accepting an access grant request agreement' do
      source_platform = create(:better_together_platform)
      target_platform = create(:better_together_platform)
      create(:better_together_platform_connection, :active, source_platform:, target_platform:)
      source_person = create(:better_together_person)
      target_person = create(:better_together_person)

      source_platform.person_platform_memberships.create!(member: source_person, role: create(:better_together_role), status: 'active')
      target_platform.person_platform_memberships.create!(member: target_person, role: create(:better_together_role), status: 'active')

      grant_offer = create(:better_together_joatu_offer, creator: source_person, target: source_person)
      grant_request = create(:better_together_joatu_person_access_grant_request, creator: target_person, target: target_person)
      agreement = create(:better_together_joatu_agreement, offer: grant_offer, request: grant_request)

      expect { agreement.accept! }.to change(BetterTogether::PersonAccessGrant.active, :count).by(1)

      grant = BetterTogether::PersonAccessGrant.order(:created_at).last
      expect(grant.allow_profile_read).to be(true)
      expect(grant.allow_private_posts).to be(false)
    end
  end
end
