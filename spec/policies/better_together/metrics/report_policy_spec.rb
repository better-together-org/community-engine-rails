# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::ReportPolicy, type: :policy do
  def grant_platform_permission(user, permission_identifier)
    BetterTogether::AccessControlBuilder.seed_data

    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host, community: user.person.community)
    role = create(:better_together_role, :platform_role)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role:)
  end

  let(:record) { :metrics_reports }
  let(:metrics_viewer) { create(:user) }
  let(:report_creator) { create(:user) }
  let(:report_downloader) { create(:user) }
  let(:manage_only_user) { create(:user) }

  before do
    grant_platform_permission(metrics_viewer, 'view_metrics_dashboard')
    grant_platform_permission(report_creator, 'create_metrics_reports')
    grant_platform_permission(report_downloader, 'download_metrics_reports')
    grant_platform_permission(manage_only_user, 'manage_platform')
  end

  it 'requires explicit dashboard permission to view metrics' do
    expect(described_class.new(metrics_viewer, record).index?).to be(true)
    expect(described_class.new(manage_only_user, record).index?).to be(false)
  end

  it 'requires explicit report creation permission' do
    expect(described_class.new(report_creator, record).create?).to be(true)
    expect(described_class.new(manage_only_user, record).create?).to be(false)
  end

  it 'requires explicit report download permission' do
    expect(described_class.new(report_downloader, record).download?).to be(true)
    expect(described_class.new(manage_only_user, record).download?).to be(false)
  end
end
