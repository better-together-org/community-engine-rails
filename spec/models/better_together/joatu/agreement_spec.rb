# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::Agreement do
  let(:creator_a) { create(:better_together_person) }
  let(:creator_b) { create(:better_together_person) }
  let(:offer)     { create(:better_together_joatu_offer, creator: creator_a) }
  let(:request)   { create(:better_together_joatu_request, creator: creator_b) }

  describe 'status transitions' do
    it 'exposes explicit participant and agreement metadata helpers' do
      agreement = create(:better_together_joatu_agreement, offer:, request:)

      expect(agreement.agreement_family).to eq('transactional_agreement')
      expect(agreement.agreement_type).to eq('transactional_agreement')
      expect(agreement.participant_people).to contain_exactly(creator_a, creator_b)
      expect(agreement.participant_ids).to contain_exactly(creator_a.id, creator_b.id)
      expect(agreement.participant_names).to contain_exactly(creator_a.name, creator_b.name)
      expect(agreement.participant_for?(creator_a)).to be(true)
      expect(agreement.participant_for?(create(:better_together_person))).to be(false)
      expect(agreement.decision_made_at).to be_nil
    end

    it 'records both creators as exchange participants' do
      agreement = create(:better_together_joatu_agreement, offer:, request:)

      expect(agreement.contributions.pluck(:role).uniq).to eq(['exchange_participant'])
      expect(agreement.contributions.pluck(:contribution_type).uniq).to eq(['community_exchange'])
      expect(agreement.contributors_for(:exchange_participant)).to contain_exactly(creator_a, creator_b)
    end

    it 'supports citations and claims on the agreement record' do
      agreement = create(:better_together_joatu_agreement, offer:, request:)
      citation = create(:better_together_citation, citeable: agreement, reference_key: 'agreement_source')
      claim = create(:better_together_claim, claimable: agreement, claim_key: 'agreement_claim')
      create(:better_together_evidence_link, claim:, citation:)

      expect(agreement.citations).to contain_exactly(citation)
      expect(agreement.claims).to contain_exactly(claim)
      expect(claim.citations).to contain_exactly(citation)
    end

    it 'starts pending' do
      agreement = described_class.new(offer:, request:)
      expect(agreement).to be_valid
      expect(agreement.status).to eq('pending')
    end

    it 'prevents changing from accepted to pending' do
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

    it 'prevents rejecting after accepted or already rejected' do
      agreement = create(:better_together_joatu_agreement, offer:, request:)
      agreement.accept!
      expect { agreement.reject! }.to raise_error(ActiveRecord::RecordInvalid)

      agreement2 = create(:better_together_joatu_agreement, offer: create(:better_together_joatu_offer),
                                                            request: create(:better_together_joatu_request))
      agreement2.reject!
      expect { agreement2.reject! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'enforces only one accepted agreement per offer and per request' do
      offer2 = create(:better_together_joatu_offer,
                      creator: creator_a)
      request2 = create(:better_together_joatu_request,
                        creator: creator_b)

      ag1 = create(:better_together_joatu_agreement, offer:, request:)
      ag2 = create(:better_together_joatu_agreement, offer:,
                                                     request: request2)
      ag3 = create(:better_together_joatu_agreement, offer: offer2,
                                                     request:)

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
      expect(agreement.agreement_type).to eq('network_connection_agreement')
      expect(agreement.decision_made_at).to be_present
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

    it 'cancels an accepted C3-priced agreement, releases the lock, and reopens both sides' do
      priced_offer = create(:better_together_joatu_offer, creator: creator_a, c3_price_millitokens: 20_000)
      agreement = create(:better_together_joatu_agreement, offer: priced_offer, request:)
      payer_balance = BetterTogether::C3::Balance.find_or_create_by!(holder: creator_b)
      payer_balance.credit!(5.0)

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

    it 'prevents cancelling an agreement before it is accepted' do
      agreement = create(:better_together_joatu_agreement, offer:, request:)

      expect { agreement.cancel! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
