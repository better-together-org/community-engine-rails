# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Entitlement and plan grant policies' do # rubocop:disable RSpec/DescribeClass
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  around do |example|
    Current.platform = host_platform
    example.run
  ensure
    Current.platform = nil
  end

  describe BetterTogether::Billing::EntitlementPolicy do
    let(:entitlement) { make_entitlement }

    it 'lets any signed-in person look at their own access, and nobody else' do
      expect(described_class.new(buyer_user, entitlement).own?).to be(true)
      expect(described_class.new(nil, entitlement).own?).to be(false)
    end

    it 'lets a steward see allowances and choose enforcement, and keeps both from a member' do
      steward_policy = described_class.new(steward_user, entitlement)
      member_policy = described_class.new(buyer_user, entitlement)

      expect([steward_policy.allowances?, steward_policy.set_enforcement?]).to all(be(true))
      expect([member_policy.allowances?, member_policy.set_enforcement?]).to all(be(false))
    end

    it 'never makes or changes one through a screen' do
      policy = described_class.new(steward_user, entitlement)

      expect([policy.index?, policy.show?, policy.create?, policy.update?, policy.destroy?]).to all(be(false))
    end
  end

  describe BetterTogether::Billing::PlanGrantPolicy do
    let(:grant) { role_grant }

    it 'lets a steward add to and remove from a platform plan' do
      policy = described_class.new(steward_user, grant)

      expect([policy.create?, policy.destroy?]).to all(be(true))
    end

    it 'keeps that from a member' do
      policy = described_class.new(buyer_user, grant)

      expect([policy.create?, policy.destroy?]).to all(be(false))
    end

    it 'refuses a seller\'s plan: a seller\'s plan cannot give roles or quotas on the platform' do
      BetterTogether::Billing::Billable.model_names << 'BetterTogether::Community'
      seller_plan = create(:better_together_billing_plan, seller: community, processor: nil, processor_price_id: nil,
                                                          accepted_payment_methods: %w[cash])
      policy = described_class.new(steward_user, seller_plan.plan_grants.build(platform_id: host_platform.id))

      expect([policy.create?, policy.destroy?]).to all(be(false))
    end
  end
end
