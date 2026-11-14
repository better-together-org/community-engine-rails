# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformConnectionNotificationService do
  subject(:service) { described_class.new(platform_connection) }

  let!(:host_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
  let(:steward_user) { create(:better_together_user, :confirmed, password: 'SecureTest123!@#') }
  let(:steward) { steward_user.person }
  let!(:platform_connection) { create(:better_together_platform_connection) }

  before do
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    ActiveJob::Base.queue_adapter.performed_jobs.clear if ActiveJob::Base.queue_adapter.respond_to?(:performed_jobs)

    permission = BetterTogether::ResourcePermission.find_or_create_by!(
      identifier: 'approve_network_connections'
    ) do |resource_permission|
      resource_permission.action = 'manage'
      resource_permission.resource_type = 'BetterTogether::Platform'
      resource_permission.name = 'Approve Network Connections'
      resource_permission.position = BetterTogether::ResourcePermission
                                     .where(resource_type: 'BetterTogether::Platform')
                                     .maximum(:position)
                                     .to_i + 1
    end

    approval_role = create(
      :better_together_role,
      :platform_role,
      identifier: "connection-approver-#{SecureRandom.hex(6)}",
      name: 'Connection Approver'
    )
    BetterTogether::RoleResourcePermission.find_or_create_by!(role: approval_role, resource_permission: permission)
    create(
      :better_together_person_platform_membership,
      member: steward,
      joinable: host_platform,
      role: approval_role
    )

    Noticed::Notification.destroy_all
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    ActiveJob::Base.queue_adapter.performed_jobs.clear if ActiveJob::Base.queue_adapter.respond_to?(:performed_jobs)
  end

  describe '#notify_submission' do
    it 'delivers a pending connection notification to network stewards' do
      expect do
        service.notify_submission
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(steward)
      expect(notification.event.type).to eq('BetterTogether::PlatformConnectionSubmittedNotifier')
    end

    it 'does not duplicate the same reviewer notification for the same connection' do
      service.notify_submission

      expect do
        service.notify_submission
      end.not_to change(Noticed::Notification, :count)
    end

    it 'collapses a burst of pending connections into a digest notification' do
      create_list(:better_together_platform_connection, 2)
      Noticed::Notification.destroy_all

      expect do
        service.notify_submission
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(steward)
      expect(notification.event.type).to eq('BetterTogether::PlatformConnectionDigestNotifier')
    end
  end

  describe '#notify_status_change' do
    it 'delivers a status-change notification for approved connections' do
      Noticed::Notification.destroy_all

      expect do
        service.notify_status_change(previous_status: 'pending')
      end.not_to change(Noticed::Notification, :count)

      expect do
        platform_connection.update!(status: 'active')
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(steward)
      expect(notification.event.type).to eq('BetterTogether::PlatformConnectionStatusNotifier')
    end
  end
end
