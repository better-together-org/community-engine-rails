# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe MembershipNotificationService do
    let(:membership) { build(:better_together_person_community_membership, :active) }

    subject(:service) { described_class.new(membership) }

    describe '#notify_creation_if_active' do
      context 'when membership is active' do
        it 'delivers membership created notification' do
          # Create membership without triggering callbacks
          membership = build(:better_together_person_community_membership, status: 'active')
          service = described_class.new(membership)

          expect do
            service.notify_creation_if_active
          end.to change(Noticed::Notification, :count).by(1)

          notification = Noticed::Notification.last
          expect(notification.recipient).to eq(membership.member)
          expect(notification.event.type).to eq('BetterTogether::MembershipCreatedNotifier')
        end
      end

      context 'when membership is not active' do
        let(:membership) { create(:better_together_person_community_membership, status: 'pending') }

        it 'does not deliver notification' do
          expect do
            service.notify_creation_if_active
          end.not_to change(Noticed::Notification, :count)
        end
      end

      context 'when member is nil' do
        before { allow(membership).to receive(:member).and_return(nil) }

        it 'does not deliver notification' do
          expect do
            service.notify_creation_if_active
          end.not_to change(Noticed::Notification, :count)
        end
      end
    end

    describe '#notify_activation' do
      let(:membership) { build(:better_together_person_community_membership, status: 'pending') }

      before do
        membership.save! # Save without triggering activation callback
        membership.update_column(:status, 'active') # Direct column update to simulate the change
      end

      it 'delivers notification when status changes from pending to active' do
        expect do
          service.notify_activation
        end.to change(Noticed::Notification, :count).by(1)

        notification = Noticed::Notification.last
        expect(notification.recipient).to eq(membership.member)
        expect(notification.event.type).to eq('BetterTogether::MembershipCreatedNotifier')
      end

      it 'does not deliver notification for other status changes' do
        membership.update_column(:status, 'pending') # Reset status

        expect do
          service.notify_activation
        end.not_to change(Noticed::Notification, :count)
      end
    end

    describe '#notify_role_update' do
      let(:old_role) { create(:better_together_role, name: 'Old Role') }
      let(:new_role) { create(:better_together_role, name: 'New Role') }
      let(:membership_with_role) { build(:better_together_person_community_membership, role: new_role) }
      let(:service) { described_class.new(membership_with_role) }

      it 'sends in-app notification when role changes' do
        expect do
          service.notify_role_update(old_role)
        end.to change(Noticed::Notification, :count).by(1)

        notification = Noticed::Notification.last
        expect(notification.event.type).to eq('BetterTogether::MembershipUpdatedNotifier')
      end

      it 'sends email notification when email is present' do
        expect(BetterTogether::MembershipMailer).to receive(:with).and_call_original
        expect_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_later) # rubocop:todo RSpec/AnyInstance

        service.notify_role_update(old_role)
      end

      it 'does not notify when old role is nil' do
        expect do
          service.notify_role_update(nil)
        end.not_to change(Noticed::Notification, :count)
      end

      it 'does not notify when roles are the same' do
        expect do
          service.notify_role_update(new_role)
        end.not_to change(Noticed::Notification, :count)
      end
    end

    describe '#notify_removal' do
      let(:member_data) do
        {
          email: 'member@example.com',
          name: 'Test Member',
          locale: I18n.default_locale,
          time_zone: Time.zone,
          role: membership.role,
          role_name: membership.role.name,
          joinable: membership.joinable,
          joinable_name: membership.joinable.name
        }
      end

      it 'sends in-app removal notification' do
        expect do
          service.notify_removal(member_data)
        end.to change(Noticed::Notification, :count).by(1)

        notification = Noticed::Notification.last
        expect(notification.event.type).to eq('BetterTogether::MembershipRemovedNotifier')
      end

      it 'sends email notification when email is present' do
        expect(BetterTogether::MembershipMailer).to receive(:with).and_call_original
        expect_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_later) # rubocop:todo RSpec/AnyInstance

        service.notify_removal(member_data)
      end

      it 'does not notify when member_data is nil' do
        expect do
          service.notify_removal(nil)
        end.not_to change(Noticed::Notification, :count)
      end

      it 'does not send email when email is blank' do
        member_data[:email] = ''

        expect(BetterTogether::MembershipMailer).not_to receive(:with)
        service.notify_removal(member_data)
      end
    end
  end
end
