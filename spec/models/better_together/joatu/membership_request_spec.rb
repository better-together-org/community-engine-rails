# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    RSpec.describe MembershipRequest do
      describe 'Factory' do
        context 'unauthenticated (no creator)' do
          subject(:mr) { build(:better_together_joatu_membership_request) }

          it 'has a valid factory' do
            expect(mr).to be_valid
          end

          it 'is unauthenticated?' do
            expect(mr).to be_unauthenticated
          end
        end

        context 'authenticated (with creator)' do
          subject(:mr) { build(:better_together_joatu_membership_request, :with_creator) }

          it 'has a valid factory' do
            expect(mr).to be_valid
          end

          it 'is not unauthenticated?' do
            expect(mr).not_to be_unauthenticated
          end
        end
      end

      describe 'validations' do
        describe 'target_type' do
          it 'is invalid when target is not a Community' do
            mr = build(:better_together_joatu_membership_request,
                       target: build(:better_together_person))
            expect(mr).not_to be_valid
            expect(mr.errors[:target]).to be_present
          end

          it 'is valid with a Community target' do
            mr = build(:better_together_joatu_membership_request)
            expect(mr).to be_valid
          end
        end

        describe 'requestor_email (unauthenticated path)' do
          it 'is required when creator is nil' do
            mr = build(:better_together_joatu_membership_request, requestor_email: nil)
            expect(mr).not_to be_valid
            expect(mr.errors[:requestor_email]).to be_present
          end

          it 'must be a valid email format' do
            mr = build(:better_together_joatu_membership_request, requestor_email: 'not-an-email')
            expect(mr).not_to be_valid
            expect(mr.errors[:requestor_email]).to be_present
          end

          it 'is not required when creator is present' do
            mr = build(:better_together_joatu_membership_request, :with_creator)
            expect(mr).to be_valid
          end
        end
      end

      describe '#after_agreement_acceptance!' do
        let(:community) { create(:better_together_community) }
        let(:approver) { create(:better_together_person) }
        let(:offer) { instance_double('BetterTogether::Joatu::Offer', creator: approver) }
        let(:community_role) do
          BetterTogether::Role.find_by(identifier: 'community_member') ||
            create(:better_together_role,
                   identifier: 'community_member',
                   resource_type: 'BetterTogether::Community')
        end

        before { community_role } # ensure role exists

        context 'unauthenticated path (no creator)' do
          subject(:mr) do
            create(:better_together_joatu_membership_request, target: community)
          end

          it 'creates a CommunityInvitation for the requestor_email' do
            expect do
              mr.after_agreement_acceptance!(offer:)
            end.to change(CommunityInvitation, :count).by(1)

            invitation = CommunityInvitation.last
            expect(invitation.invitee_email).to eq(mr.requestor_email)
            expect(invitation.invitable).to eq(community)
            expect(invitation.inviter).to eq(approver)
            expect(invitation.status_pending?).to be true
          end
        end

        context 'authenticated path (with creator)' do
          let(:person) { create(:better_together_person) }
          subject(:mr) do
            create(:better_together_joatu_membership_request, :with_creator,
                   creator: person, target: community)
          end

          it 'creates a PersonCommunityMembership for the creator' do
            expect do
              mr.after_agreement_acceptance!(offer:)
            end.to change(PersonCommunityMembership, :count).by(1)

            membership = PersonCommunityMembership.last
            expect(membership.member).to eq(person)
            expect(membership.joinable).to eq(community)
            expect(membership.role).to eq(community_role)
          end

          it 'is idempotent — does not duplicate membership' do
            mr.after_agreement_acceptance!(offer:)
            expect do
              mr.after_agreement_acceptance!(offer:)
            end.not_to change(PersonCommunityMembership, :count)
          end
        end
      end
    end
  end
end
