# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe PersonPlatformMembership do
    subject(:person_platform_membership) { build(:better_together_person_platform_membership) }

    describe 'Factory' do
      it 'has a valid factory' do
        expect(person_platform_membership).to be_valid
      end
    end

    describe 'ActiveRecord associations' do
      it { is_expected.to belong_to(:joinable) }
      it { is_expected.to belong_to(:member).class_name('BetterTogether::Person') }
      it { is_expected.to belong_to(:role) }
    end

    describe 'Attributes' do
      it { is_expected.to respond_to(:member_id) }
      it { is_expected.to respond_to(:joinable_id) }
      it { is_expected.to respond_to(:role_id) }
      it { is_expected.to respond_to(:status) }
    end

    describe 'status enum' do
      it 'defines status enum with correct values and defaults' do
        expect(person_platform_membership)
          .to define_enum_for(:status)
          .with_values(pending: 'pending', active: 'active')
          .backed_by_column_of_type(:string)
          .with_default('pending')
      end

      describe 'scopes' do
        let!(:pending_membership) { create(:better_together_person_platform_membership, status: 'pending') }
        let!(:active_membership) { create(:better_together_person_platform_membership, status: 'active') }

        it 'includes pending memberships in pending scope' do
          expect(described_class.pending).to include(pending_membership)
          expect(described_class.pending).not_to include(active_membership)
        end

        it 'includes active memberships in active scope' do
          expect(described_class.active).to include(active_membership)
          expect(described_class.active).not_to include(pending_membership)
        end
      end

      describe '#activate!' do
        let(:membership) { create(:better_together_person_platform_membership, status: 'pending') }

        it 'changes status to active' do
          expect { membership.activate! }.to change(membership, :status).from('pending').to('active')
        end
      end
    end

    describe 'notifications' do
      it 'creates a membership created notification for active memberships' do
        membership = build(:better_together_person_platform_membership, status: 'active')

        expect do
          membership.save!
        end.to change(Noticed::Notification, :count).by(1)

        notification = Noticed::Notification.last
        expect(notification.recipient).to eq(membership.member)
        expect(notification.event.type).to eq('BetterTogether::MembershipCreatedNotifier')
        expect(notification.event.record).to eq(membership)
      end

      it 'does not create notification for pending memberships' do
        membership = build(:better_together_person_platform_membership, status: 'pending')

        expect do
          membership.save!
        end.not_to change(Noticed::Notification, :count)
      end

      it 'creates notification when membership is activated' do
        membership = create(:better_together_person_platform_membership, status: 'pending')

        expect do
          membership.activate!
        end.to change(Noticed::Notification, :count).by(1)

        notification = Noticed::Notification.last
        expect(notification.recipient).to eq(membership.member)
        expect(notification.event.type).to eq('BetterTogether::MembershipCreatedNotifier')
        expect(notification.event.record).to eq(membership)
      end

      it 'cleans up related notifications when membership is destroyed' do
        membership = create(:better_together_person_platform_membership, status: 'active')

        # Verify notification was created
        expect(Noticed::Notification.count).to eq(1)

        # Expect cleanup job to be enqueued
        expect do
          membership.destroy!
        end.to have_enqueued_job(BetterTogether::CleanupNotificationsJob)
          .with(record_type: 'BetterTogether::PersonPlatformMembership', record_id: membership.id)
      end
    end

    describe 'email notifications' do
      let(:membership) { create(:better_together_person_platform_membership) }
      let(:new_role) { create(:better_together_role, resource_type: 'BetterTogether::Platform') }

      it 'sends an email when role is updated' do
        expect do
          membership.update!(role: new_role)
        end.to have_enqueued_mail(BetterTogether::MembershipMailer, :updated)
      end

      it 'does not send an email when other attributes are updated' do
        expect do
          membership.update!(updated_at: 1.day.from_now)
        end.not_to have_enqueued_mail(BetterTogether::MembershipMailer, :updated)
      end

      it 'sends an email when membership is destroyed' do
        expect do
          membership.destroy!
        end.to have_enqueued_mail(BetterTogether::MembershipMailer, :removed)
      end
    end

    describe 'in-app notifications' do
      it 'creates notification when role is updated' do
        membership = create(:better_together_person_platform_membership)
        new_role = create(:better_together_role, resource_type: 'BetterTogether::Platform')

        # Clear any existing notifications
        Noticed::Notification.destroy_all

        expect do
          membership.update!(role: new_role)
        end.to change(Noticed::Notification, :count).by(1)

        notification = Noticed::Notification.last
        expect(notification.recipient).to eq(membership.member)
        expect(notification.event.type).to eq('BetterTogether::MembershipUpdatedNotifier')
        expect(notification.event.record).to eq(membership)
      end

      it 'creates notification when membership is destroyed' do
        membership = create(:better_together_person_platform_membership, status: 'active')

        # Initial notification from creation
        expect(Noticed::Notification.count).to eq(1)

        expect do
          membership.destroy!
        end.to change(Noticed::Notification, :count).by(1)

        # Should have removal notification sent to the member
        notifications = Noticed::Notification.all
        removal_notification = notifications.find { |n| n.event.type == 'BetterTogether::MembershipRemovedNotifier' }
        expect(removal_notification).to be_present
        expect(removal_notification.recipient).to eq(membership.member)
        expect(removal_notification.event.record).to eq(membership.joinable)
      end

      it 'does not create notification when other attributes are updated' do
        membership = create(:better_together_person_platform_membership)
        initial_count = Noticed::Notification.count

        membership.update!(updated_at: 1.day.from_now)

        expect(Noticed::Notification.count).to eq(initial_count)
      end
    end
  end
end
