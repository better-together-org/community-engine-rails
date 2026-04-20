# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ReportPolicy do
  def grant_platform_permission(user, permission_identifier)
    BetterTogether::AccessControlBuilder.seed_data

    host_platform = BetterTogether::Platform.find_by(host: true) ||
                    create(:better_together_platform, :host, community: user.person.community)
    role = create(:better_together_role, :platform_role)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)
    role.assign_resource_permissions([permission.identifier])
    host_platform.person_platform_memberships.find_or_create_by!(member: user.person, role:)
  end

  let(:user) { create(:better_together_user, :confirmed) }
  let(:agent) { user.person }
  let(:other) { create(:better_together_person) }
  let(:platform_manager) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:safety_reviewer) { create(:better_together_user, :confirmed) }

  before do
    grant_platform_permission(safety_reviewer, 'manage_platform_safety')
  end

  it 'permits create when reporter is agent and reportable is different' do
    record = BetterTogether::Report.new(
      reporter: agent,
      reportable: other,
      reason: 'spam',
      category: 'spam_or_scam',
      harm_level: 'medium',
      requested_outcome: 'content_review'
    )
    expect(described_class.new(user, record).create?).to be true
  end

  it 'denies create when reporter is not agent' do
    record = BetterTogether::Report.new(
      reporter: other,
      reportable: agent,
      reason: 'spam',
      category: 'spam_or_scam',
      harm_level: 'medium',
      requested_outcome: 'content_review'
    )
    expect(described_class.new(user, record).create?).to be false
  end

  it 'denies create when reporter equals reportable' do
    record = BetterTogether::Report.new(
      reporter: agent,
      reportable: agent,
      reason: 'spam',
      category: 'spam_or_scam',
      harm_level: 'medium',
      requested_outcome: 'content_review'
    )
    expect(described_class.new(user, record).create?).to be false
  end

  it 'denies create when reportable is missing' do
    record = BetterTogether::Report.new(
      reporter: agent,
      reason: 'spam',
      category: 'spam_or_scam',
      harm_level: 'medium',
      requested_outcome: 'content_review'
    )
    expect(described_class.new(user, record).create?).to be false
  end

  it 'denies create when the reportable record belongs to the reporter' do
    post = create(:better_together_post, author: agent)
    record = BetterTogether::Report.new(
      reporter: agent,
      reportable: post,
      reason: 'spam',
      category: 'spam_or_scam',
      harm_level: 'medium',
      requested_outcome: 'content_review'
    )

    expect(described_class.new(user, record).create?).to be false
  end

  describe '#show?' do
    let(:submitted_report) { create(:report, reporter: user.person, reportable: other) }

    it 'allows the reporting person' do
      expect(described_class.new(user, submitted_report).show?).to be true
    end

    it 'denies default platform managers without explicit safety authority' do
      expect(described_class.new(platform_manager, submitted_report).show?).to be false
    end

    it 'allows explicit safety reviewers' do
      expect(described_class.new(safety_reviewer, submitted_report).show?).to be true
    end
  end

  describe '#add_followup?' do
    let(:submitted_report) { create(:report, reporter: user.person, reportable: other) }

    it 'allows the reporting person to add followup notes' do
      expect(described_class.new(user, submitted_report).add_followup?).to be true
    end

    it 'denies safety reviewers through the reporter followup path' do
      expect(described_class.new(safety_reviewer, submitted_report).add_followup?).to be false
    end
  end

  describe 'Scope' do
    let!(:own_report) { create(:report, reporter: user.person, reportable: other) }
    let!(:other_report) { create(:report) }

    it 'returns only the reporter records by default' do
      scope = described_class::Scope.new(user, BetterTogether::Report).resolve

      expect(scope).to include(own_report)
      expect(scope).not_to include(other_report)
    end

    it 'returns all reports for explicit safety reviewers' do
      scope = described_class::Scope.new(safety_reviewer, BetterTogether::Report).resolve

      expect(scope).to include(own_report, other_report)
    end
  end
end
