# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::AgreementRequirement do
  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'

  let(:agreement) do
    create(:better_together_agreement, agreement_kind: 'transactional_agreement', platform: host_platform, identifier: 'terms-a')
  end

  def requirement(**attrs)
    host_platform.billing_agreement_requirements.build({ agreement:, mode: 'additional' }.merge(attrs))
  end

  describe 'its platform' do
    it 'is required, and never guessed from the host' do
      Current.platform = nil
      built = described_class.new(agreement:, mode: 'additional')

      expect(built).not_to be_valid
      expect(built.platform).to be_nil
    end

    it 'is the current request platform when none is given and the agreement is the same platform\'s' do
      Current.platform = host_platform
      built = described_class.new(agreement:, mode: 'additional')

      expect(built).to be_valid
      expect(built.platform).to eq(host_platform)
    ensure
      Current.platform = nil
    end

    it 'is found through its platform, with a NOT NULL column' do
      saved = requirement.tap(&:save!)

      expect(described_class.for_platform(host_platform)).to include(saved)
      expect(described_class.for_platform(create(:better_together_platform))).not_to include(saved)
      expect(described_class.columns_hash.fetch('platform_id').null).to be(false)
    end
  end

  it 'is the platform\'s default when it has no target' do
    expect(requirement).to be_valid
    expect(requirement).to be_platform_default
    expect(requirement.specificity).to eq(0)
  end

  it 'can be limited to one kind of purchase and one payment method' do
    expect(requirement(purpose: 'ticket', payment_method: 'cash')).to be_valid
    expect(requirement(purpose: 'barter')).not_to be_valid
    expect(requirement(payment_method: 'bitcoin')).not_to be_valid
    expect(requirement(payment_method: 'fake')).not_to be_valid
  end

  it 'treats an empty purpose or method as none' do
    built = requirement(purpose: '', payment_method: '')
    built.valid?

    expect(built).to have_attributes(purpose: nil, payment_method: nil)
  end

  it 'knows whether it replaces the defaults' do
    expect(requirement(mode: 'replaces_default')).to be_replaces_default
    expect(requirement(mode: 'sometimes')).not_to be_valid
  end

  describe 'its agreement' do
    it 'must be a purchase agreement, not a registration policy' do
      policy = create(:better_together_agreement, agreement_kind: 'policy_consent', platform: host_platform, identifier: 'policy-a')

      expect(requirement(agreement: policy)).not_to be_valid
    end

    it 'must be on the same platform' do
      other = create(:better_together_platform)
      foreign = create(:better_together_agreement, agreement_kind: 'transactional_agreement', platform: other, identifier: 'terms-f')
      built = requirement(agreement: foreign)

      expect(built).not_to be_valid
      expect(built.errors.details[:platform]).to include(a_hash_including(error: :platform_owner_mismatch))
    end

    it 'is required' do
      expect(requirement(agreement: nil)).not_to be_valid
    end
  end

  describe 'its target' do
    it 'can be a plan, which is the most specific', :aggregate_failures do
      built = requirement(target: plan)

      expect(built).to be_valid
      expect(built.specificity).to eq(2)
    end

    it 'can be a seller, which is in between' do
      community = create(:better_together_community)
      built = requirement(target: community)

      expect(built).to be_valid
      expect(built.specificity).to eq(1)
    end

    it 'is limited to registered types, never loading one from a string' do
      built = requirement
      built.assign_attributes(target_type: 'Kernel', target_id: SecureRandom.uuid)

      expect(built).not_to be_valid
      expect(built.errors.details[:target_type]).to include(a_hash_including(error: :inclusion))
    end

    it 'must be on the same platform' do
      community = create(:better_together_community)
      other_id = create(:better_together_platform).id
      community.define_singleton_method(:billing_bound_platform_id) { other_id }

      expect(requirement(target: community)).not_to be_valid
    end
  end

  it 'cannot repeat the same requirement' do
    requirement(purpose: 'ticket').save!

    expect(requirement(purpose: 'ticket')).not_to be_valid
    expect(requirement(purpose: 'one_time')).to be_valid
  end

  it 'is reached through its platform' do
    saved = requirement.tap(&:save!)

    expect(host_platform.billing_agreement_requirements).to include(saved)
  end
end
