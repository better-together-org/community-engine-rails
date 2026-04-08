# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::MembershipRequestNotificationService do
  subject(:service) { described_class.new(membership_request) }

  let(:community) { create(:better_together_community, :membership_requests_enabled) }
  let(:community_manager_role) do
    BetterTogether::Role.find_by(identifier: 'community_manager',
                                 resource_type: 'BetterTogether::Community') ||
      create(:better_together_role,
             identifier: 'community_manager',
             name: 'Community Manager',
             resource_type: 'BetterTogether::Community')
  end
  let(:manager_user) { create(:better_together_user, :confirmed, password: 'SecureTest123!@#') }
  let(:manager) { manager_user.person }
  let!(:manager_membership) do
    create(:better_together_person_community_membership,
           :active,
           joinable: community,
           member: manager,
           role: community_manager_role)
  end
  let!(:membership_request) { create(:better_together_joatu_membership_request, target: community) }
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

  describe '#notify_submission' do
    it 'delivers reviewer notifications' do
      Noticed::Notification.destroy_all
      reset_test_jobs.call

      expect do
        service.notify_submission
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(manager)
      expect(notification.event.type).to eq('BetterTogether::MembershipRequestSubmittedNotifier')
    end
  end

  describe '#notify_approval' do
    context 'when the requester has an account' do
      let(:requester) { create(:better_together_user, :confirmed, password: 'SecureTest123!@#').person }
      let(:membership_request) do
        create(:better_together_joatu_membership_request, :with_creator, target: community, creator: requester)
      end

      it 'does not send a duplicate request-decision notification' do
        reset_test_jobs.call

        expect do
          service.notify_approval
        end.not_to change(Noticed::Notification, :count)
      end
    end

    context 'when the requester is email-only' do
      let!(:invitation) do
        create(
          :better_together_community_invitation,
          invitable: community,
          invitee_email: membership_request.requestor_email,
          inviter: manager,
          locale: I18n.default_locale.to_s
        )
      end

      it 'sends the community invitation email' do
        reset_test_jobs.call

        expect do
          service.notify_approval(approval_invitation: invitation)
        end.to have_enqueued_mail(BetterTogether::CommunityInvitationsMailer, :invite)
      end
    end
  end

  describe '#notify_decline' do
    context 'when the requester has an account' do
      let(:requester) { create(:better_together_user, :confirmed, password: 'SecureTest123!@#').person }
      let(:membership_request) do
        create(:better_together_joatu_membership_request, :with_creator, target: community, creator: requester)
      end

      it 'delivers in-app and email decline notifications' do
        reset_test_jobs.call

        expect do
          service.notify_decline(decision_actor: manager)
        end.to change(Noticed::Notification, :count).by(1)

        enqueued_job = ActiveJob::Base.queue_adapter.enqueued_jobs.last
        expect(enqueued_job['job_class']).to eq('ActionMailer::MailDeliveryJob')
        expect(enqueued_job['arguments'][0]).to eq('BetterTogether::MembershipRequestMailer')
        expect(enqueued_job['arguments'][1]).to eq('declined')

        notification = Noticed::Notification.last
        expect(notification.recipient).to eq(requester)
        expect(notification.event.type).to eq('BetterTogether::MembershipRequestDeclinedNotifier')
      end
    end

    context 'when the requester is email-only' do
      it 'emails the requester directly' do
        reset_test_jobs.call

        expect do
          service.notify_decline(decision_actor: manager)
        end.to have_enqueued_mail(BetterTogether::MembershipRequestMailer, :declined)
      end
    end
  end
end
