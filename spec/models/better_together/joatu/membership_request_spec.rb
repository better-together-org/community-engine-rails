# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu # rubocop:todo Metrics/ModuleLength
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
        let(:offer) { instance_double(BetterTogether::Joatu::Offer, creator: approver) }
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

          it 'activates an existing pending membership for the creator' do
            membership = create(
              :better_together_person_community_membership,
              joinable: community,
              member: person,
              role: community_role,
              status: 'pending'
            )

            expect do
              mr.after_agreement_acceptance!(offer:)
            end.not_to change(PersonCommunityMembership, :count)

            expect(membership.reload.status).to eq('active')
          end
        end
      end

      describe 'notifications' do
        let(:community) { create(:better_together_community, :membership_requests_enabled) }
        let(:community_manager_role) do
          BetterTogether::Role.find_by(identifier: 'community_manager',
                                       resource_type: 'BetterTogether::Community') ||
            create(:better_together_role,
                   identifier: 'community_manager',
                   name: 'Community Manager',
                   resource_type: 'BetterTogether::Community')
        end
        let(:manager_user) do
          create(:better_together_user, :confirmed, password: 'SecureTest123!@#')
        end
        let(:manager) { manager_user.person }
        let!(:manager_membership) do
          create(:better_together_person_community_membership,
                 :active,
                 joinable: community,
                 member: manager,
                 role: community_manager_role)
        end
        let(:reset_test_jobs) do
          lambda do
            next unless ActiveJob::Base.queue_adapter.respond_to?(:enqueued_jobs)

            ActiveJob::Base.queue_adapter.enqueued_jobs.clear
            ActiveJob::Base.queue_adapter.performed_jobs.clear if ActiveJob::Base.queue_adapter.respond_to?(:performed_jobs)
          end
        end

        before do
          ActiveJob::Base.queue_adapter = :test
          reset_test_jobs.call
          Noticed::Notification.destroy_all
        end

        it 'notifies reviewers when a request is submitted' do
          expect do
            create(:better_together_joatu_membership_request, target: community)
          end.to change(Noticed::Notification, :count).by(1)

          notification = Noticed::Notification.last
          expect(notification.recipient).to eq(manager)
          expect(notification.event.type).to eq('BetterTogether::MembershipRequestSubmittedNotifier')
        end

        it 'notifies an authenticated requester when approved' do
          requester = create(:better_together_user, :confirmed, password: 'SecureTest123!@#').person
          request = create(
            :better_together_joatu_membership_request,
            :with_creator,
            target: community,
            creator: requester
          )

          Noticed::Notification.destroy_all
          reset_test_jobs.call

          expect do
            request.approve!(approver: manager)
          end.to change(Noticed::Notification, :count).by(1)

          notification = Noticed::Notification.last
          expect(notification.recipient).to eq(requester)
          expect(notification.event.type).to eq('BetterTogether::MembershipCreatedNotifier')
        end

        it 'sends an invitation email for an unauthenticated approval' do
          request = create(:better_together_joatu_membership_request, target: community)

          reset_test_jobs.call

          expect do
            request.approve!(approver: manager)
          end.to have_enqueued_mail(BetterTogether::CommunityInvitationsMailer, :invite)
        end

        it 'notifies an authenticated requester when declined' do
          requester = create(:better_together_user, :confirmed, password: 'SecureTest123!@#').person
          request = create(
            :better_together_joatu_membership_request,
            :with_creator,
            target: community,
            creator: requester
          )

          Noticed::Notification.destroy_all
          reset_test_jobs.call

          expect do
            request.decline!
          end.to change(Noticed::Notification, :count).by(1)

          enqueued_job = ActiveJob::Base.queue_adapter.enqueued_jobs.last
          expect(enqueued_job['job_class']).to eq('ActionMailer::MailDeliveryJob')
          expect(enqueued_job['arguments'][0]).to eq('BetterTogether::MembershipRequestMailer')
          expect(enqueued_job['arguments'][1]).to eq('declined')

          notification = Noticed::Notification.last
          expect(notification.recipient).to eq(requester)
          expect(notification.event.type).to eq('BetterTogether::MembershipRequestDeclinedNotifier')
        end

        it 'emails an unauthenticated requester when declined' do
          request = create(:better_together_joatu_membership_request, target: community)

          reset_test_jobs.call

          expect do
            request.decline!
          end.to have_enqueued_mail(BetterTogether::MembershipRequestMailer, :declined)
        end
      end
    end
  end
end
