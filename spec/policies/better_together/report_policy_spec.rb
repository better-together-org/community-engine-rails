# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ReportPolicy do
  let(:user) { create(:better_together_user, :confirmed) }
  let(:agent) { user.person }
  let(:other) { create(:better_together_person) }

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
end
