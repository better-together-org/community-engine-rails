# frozen_string_literal: true

require 'rails_helper'

# An add-on is a plain extra: one-time, with nothing included in it.
RSpec.describe BetterTogether::Billing::Plan do
  include_context 'with entitlement fixtures'

  let(:attrs) { { platform: host_platform, processor: nil, accepted_payment_methods: %w[cash], currency: 'USD' } }

  def plan_with(**more) = build(:better_together_billing_plan, :unlinked, :one_time, **attrs, **more)
  def error_keys(record) = record.errors.details.values.flatten.pluck(:error)

  describe 'an add-on' do
    it 'is valid when one-time and without grants' do
      expect(plan_with(add_on: true)).to be_valid
    end

    it 'refuses to renew' do
      plan = plan_with(add_on: true, billing_interval: 'month')

      expect(plan).not_to be_valid
      expect(error_keys(plan)).to include(:add_on_cannot_renew)
    end

    it 'cannot be made from a plan that already includes something' do
      plan = plan_with.tap(&:save!)
      add_grant('feature_access', { 'feature_key' => 'device_permissions', 'access_level' => 'beta' }, plan:)

      expect(plan.update(add_on: true)).to be(false)
      expect(error_keys(plan)).to include(:add_on_has_grants)
    end

    it 'refuses a grant added to it' do
      plan = plan_with(add_on: true).tap(&:save!)
      grant = plan.plan_grants.build(platform_id: host_platform.id, kind: 'feature_access', position: 0,
                                     parameters: { 'feature_key' => 'device_permissions', 'access_level' => 'beta' })

      expect(grant).not_to be_valid
      expect(error_keys(grant)).to include(:add_on_cannot_have_grants)
    end

    it 'cannot change kind once an order line references it' do
      plan = plan_with.tap(&:save!)
      allow(BetterTogether::Billing::LineItem).to receive(:exists?).with(purchasable: plan).and_return(true)

      expect(plan.update(add_on: true)).to be(false)
      expect(error_keys(plan)).to include(:add_on_locked_by_orders)
    end

    it 'is left out of the primary scope' do
      add_on = plan_with(add_on: true).tap(&:save!)

      expect(described_class.primary).not_to include(add_on)
      expect(described_class.add_on).to include(add_on)
    end
  end
end
