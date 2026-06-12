# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SafetyReportNotificationService do
  subject(:service) { described_class.new(report) }

  let!(:host_platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
  let(:safety_reviewer_user) { create(:better_together_user, :confirmed, password: 'SecureTest123!@#') }
  let(:safety_reviewer) { safety_reviewer_user.person }
  let!(:report) { create(:report) }

  before do
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    ActiveJob::Base.queue_adapter.performed_jobs.clear if ActiveJob::Base.queue_adapter.respond_to?(:performed_jobs)

    permission = BetterTogether::ResourcePermission.find_or_create_by!(
      identifier: 'manage_platform_safety'
    ) do |resource_permission|
      resource_permission.action = 'manage'
      resource_permission.resource_type = 'BetterTogether::Platform'
      resource_permission.name = 'Manage Platform Safety'
      resource_permission.position = BetterTogether::ResourcePermission
                                     .where(resource_type: 'BetterTogether::Platform')
                                     .maximum(:position)
                                     .to_i + 1
    end

    role = create(
      :better_together_role,
      :platform_role,
      identifier: "safety-reviewer-#{SecureRandom.hex(6)}",
      name: 'Safety Reviewer'
    )
    BetterTogether::RoleResourcePermission.find_or_create_by!(role:, resource_permission: permission)
    create(
      :better_together_person_platform_membership,
      member: safety_reviewer,
      joinable: host_platform,
      role:
    )

    Noticed::Notification.destroy_all
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    ActiveJob::Base.queue_adapter.performed_jobs.clear if ActiveJob::Base.queue_adapter.respond_to?(:performed_jobs)
  end

  describe '#notify_submission' do
    it 'delivers an in-app notification to safety reviewers' do
      expect do
        service.notify_submission
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(safety_reviewer)
      expect(notification.event.type).to eq('BetterTogether::SafetyReportSubmittedNotifier')
    end

    it 'does not duplicate the same reviewer notification for the same report' do
      service.notify_submission

      expect do
        service.notify_submission
      end.not_to change(Noticed::Notification, :count)
    end

    it 'collapses a burst of reports into a digest notification' do
      create_list(:report, 2)
      Noticed::Notification.destroy_all

      expect do
        service.notify_submission
      end.to change(Noticed::Notification, :count).by(1)

      notification = Noticed::Notification.last
      expect(notification.recipient).to eq(safety_reviewer)
      expect(notification.event.type).to eq('BetterTogether::SafetyReportDigestNotifier')
      expect(
        Noticed::Notification.includes(:event).where(recipient: safety_reviewer).map { |item| item.event.type }
      ).not_to include('BetterTogether::SafetyReportSubmittedNotifier')
    end

    it 'suppresses repeat digest notifications during the cooldown window' do
      create_list(:report, 2)
      Noticed::Notification.destroy_all

      service.notify_submission

      follow_up_report = create(:report)
      follow_up_service = described_class.new(follow_up_report)

      expect do
        follow_up_service.notify_submission
      end.not_to change(Noticed::Notification, :count)

      expect(Noticed::Notification.last.event.type).to eq('BetterTogether::SafetyReportDigestNotifier')
    end
  end
end
