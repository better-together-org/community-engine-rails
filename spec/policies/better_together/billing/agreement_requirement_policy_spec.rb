# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::AgreementRequirementPolicy do
  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:other_platform) { create(:better_together_platform) }
  let(:requirement) { host_platform.billing_agreement_requirements.first || create(:better_together_billing_agreement_requirement) }
  let(:steward) { find_or_create_test_user("req-policy-steward-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :platform_manager) }
  let(:member) { find_or_create_test_user("req-policy-member-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }

  around do |example|
    Current.platform = host_platform
    example.run
  ensure
    Current.platform = nil
  end

  %i[index? create? destroy?].each do |action|
    it "allows a steward to #{action}, even before a payment method is on" do
      expect(BetterTogether::Billing.enabled?(host_platform)).to be(true).or be(false)
      expect(described_class.new(steward, requirement).public_send(action)).to be(true)
    end

    it "refuses a member and a visitor to #{action}" do
      expect(described_class.new(member, requirement).public_send(action)).to be(false)
      expect(described_class.new(nil, requirement).public_send(action)).to be(false)
    end
  end

  it 'never offers show or update' do
    expect([described_class.new(steward, requirement).show?, described_class.new(steward, requirement).update?]).to all(be(false))
  end

  it 'refuses a requirement of another platform' do
    foreign = create(:better_together_agreement, agreement_kind: 'transactional_agreement', platform: other_platform,
                                                 identifier: 'foreign-terms')
              .then do |agreement|
      other_platform.billing_agreement_requirements.create!(agreement:, mode: 'additional')
    end

    expect(described_class.new(steward, foreign).destroy?).to be(false)
  end

  it 'is refused while billing is not switched on for the host' do
    allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

    expect(described_class.new(steward, requirement).index?).to be(false)
  end

  it 'scopes to the platform\'s own requirements for a steward' do
    mine = requirement
    foreign_agreement = create(:better_together_agreement, agreement_kind: 'transactional_agreement', platform: other_platform,
                                                           identifier: 'foreign-2')
    foreign = other_platform.billing_agreement_requirements.create!(agreement: foreign_agreement, mode: 'additional')

    resolved = described_class::Scope.new(steward, BetterTogether::Billing::AgreementRequirement).resolve

    expect(resolved).to include(mine)
    expect(resolved).not_to include(foreign)
    expect(described_class::Scope.new(member, BetterTogether::Billing::AgreementRequirement).resolve).to be_empty
  end
end
