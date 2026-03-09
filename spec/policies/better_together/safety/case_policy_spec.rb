# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Safety::CasePolicy do
  let(:platform_manager) { create(:better_together_user, :confirmed, :platform_manager) }
  let(:reporter_user) { create(:better_together_user, :confirmed) }
  let(:other_user) { create(:better_together_user, :confirmed) }
  let(:safety_case) { create(:report, reporter: reporter_user.person).safety_case }

  it 'permits platform managers to view and update cases' do
    policy = described_class.new(platform_manager, safety_case)
    expect(policy.show?).to be true
    expect(policy.update?).to be true
  end

  it 'permits reporters to view their own case' do
    policy = described_class.new(reporter_user, safety_case)
    expect(policy.show?).to be true
    expect(policy.update?).to be false
  end

  it 'denies unrelated users' do
    policy = described_class.new(other_user, safety_case)
    expect(policy.show?).to be false
  end
end
