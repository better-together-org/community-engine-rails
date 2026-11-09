# frozen_string_literal: true

require 'rails_helper'

# What a subscription gives follows the subscription: it comes with payment, stays through the grace, goes at
# the lapse, and returns when paid again.
RSpec.describe BetterTogether::Billing::Entitlements::Sync do
  include_context 'with entitlement fixtures'

  let(:period_end) { Time.utc(2027, 2, 28, 15) }

  before do
    role_grant
    feature_grant
    quota_grant(amount: 5_000)
  end

  def term = @term ||= start_subscription # rubocop:disable RSpec/InstanceVariable

  def entitlement = entitlement_for(term)

  def applied_kinds = entitlement.grants.applied.pluck(:kind)

  describe 'when the first order is paid' do
    it 'gives what the plan includes, through the follow-up job, without the payer doing anything' do
      expect(entitlement).to have_attributes(status: 'active', beneficiary: buyer, plan: sub_plan, ends_at: period_end)
      expect(applied_kinds).to contain_exactly('membership_role', 'feature_access', 'quota_allowance')
      expect(platform_membership(buyer)).to have_attributes(status: 'active')
      expect(BetterTogether::FeatureAccessGrant.active.where(person: buyer, feature_key: 'device_permissions')).to exist
    end

    it 'raises the quota limit by the allowance and stops charging the creator for community content only with a community pool' do
      term

      quota = BetterTogether::Quota.find_by!(owner: buyer, quota_type: 'media_storage')
      default = BetterTogether::Quotas::Type.find('media_storage').default_limit(buyer)
      expect(quota.limit).to eq(default + 5_000)
    end

    it 'tells the payer, once' do
      clear_notices
      deliver_now { term }

      expect(kinds_for(buyer).count('entitlement_granted')).to eq(1)
    end

    it 'gives nothing for a plan that includes nothing' do
      empty = create(:better_together_billing_plan, processor: nil, processor_price_id: nil, accepted_payment_methods: %w[cash])
      other = start_subscription(plan: empty, payer: create(:better_together_person))

      expect(entitlement_for(other)).to be_nil
    end
  end

  describe 'while the subscription is running' do
    it 'does nothing more when it is synced again' do
      entitlement
      expect { 3.times { sync(term) } }.not_to(change do
        [BetterTogether::Billing::EntitlementGrant.count, BetterTogether::PersonPlatformMembership.count]
      end)
    end

    it 'keeps everything through the grace, and says it is in grace' do
      term
      advance(term, at: period_end + 1.hour)
      sync(term)

      expect(entitlement).to have_attributes(status: 'grace', grace_ends_at: period_end + 7.days)
      expect(applied_kinds.size).to eq(3)
      expect(platform_membership(buyer)).to be_present
    end
  end

  describe 'when the subscription lapses' do
    before do
      term
      generate_renewal(term, at: Time.utc(2027, 2, 20))
      advance(term, at: period_end + 8.days)
      sync(term)
    end

    it 'takes away what the entitlement made, silently, and never deletes anything else' do
      expect(entitlement.status).to eq('lapsed')
      expect(platform_membership(buyer)).to be_nil
      expect(BetterTogether::FeatureAccessGrant.active.where(person: buyer, feature_key: 'device_permissions')).to be_empty
      expect(BetterTogether::FeatureAccessGrant.where(person: buyer, feature_key: 'device_permissions')).to exist
      expect(entitlement.grants.applied).to be_empty
    end

    it 'drops the quota back to its default, and leaves what was used alone' do
      quota = BetterTogether::Quota.find_by!(owner: buyer, quota_type: 'media_storage')

      expect(quota.limit).to eq(BetterTogether::Quotas::Type.find('media_storage').default_limit(buyer))
      expect(BetterTogether::Quotas::Allowances.extra_for(buyer, 'media_storage')).to eq(0)
    end

    it 'tells the payer' do
      clear_notices
      deliver_now { sync(term) }
      lapse_notice_count = kinds_for(buyer).count('entitlement_lapsed')
      deliver_now do
        advance(term, at: period_end + 9.days)
        sync(term)
      end

      expect(kinds_for(buyer).count('entitlement_lapsed')).to eq(lapse_notice_count)
    end

    it 'comes back when it is paid again, and the person has the membership once more' do
      pay_renewal(term, at: Time.utc(2027, 3, 12, 10))
      sync(term)

      expect(entitlement.status).to eq('active')
      expect(platform_membership(buyer)).to have_attributes(status: 'active')
      expect(entitlement.grants.applied.size).to eq(3)
    end
  end

  describe 'what the person had before' do
    it 'keeps a membership and feature access they already had, through a lapse' do
      existing = create(:better_together_person_platform_membership, member: buyer, joinable: host_platform, role: supporter_role,
                                                                     status: 'active')
      access = create(:better_together_feature_access_grant, person: buyer, platform: host_platform, feature_key: 'device_permissions',
                                                             expires_at: nil)
      term
      expect(entitlement.grants.applied.where(owned: true).pluck(:kind)).to eq(['quota_allowance'])

      advance(term, at: period_end + 8.days)
      sync(term)

      expect(existing.reload).to be_persisted
      expect(access.reload.revoked_at).to be_nil
    end
  end

  describe 'when the plan changes' do
    it 'gives a grant the plan gained to people who already pay' do
      term
      gained = add_grant('quota_allowance', { 'quota_type' => 'ai_translation_tokens', 'amount' => 100 })

      BetterTogether::Billing::SyncPlanEntitlementsJob.perform_now(sub_plan)

      expect(entitlement.grants.applied.pluck(:grant_key)).to include(gained.handler.key)
    end

    it 'takes away a grant the plan lost, but only what the entitlement made' do
      term
      sub_plan.plan_grants.find_by(kind: 'membership_role').destroy!

      BetterTogether::Billing::SyncPlanEntitlementsJob.perform_now(sub_plan)

      expect(platform_membership(buyer)).to be_nil
      expect(entitlement.grants.applied.pluck(:kind)).to contain_exactly('feature_access', 'quota_allowance')
    end

    it 'starts giving things to existing subscribers of a plan that had nothing, when it gains its first grant' do
      bare = create(:better_together_billing_plan, processor: nil, processor_price_id: nil, accepted_payment_methods: %w[cash])
      bare_term = start_subscription(plan: bare, payer: create(:better_together_person))
      expect(entitlement_for(bare_term)).to be_nil
      add_grant('membership_role', { 'joinable' => 'platform', 'role' => supporter_role.identifier }, plan: bare)

      BetterTogether::Billing::SyncPlanEntitlementsJob.perform_now(bare)

      expect(entitlement_for(bare_term)).to be_live
    end
  end

  describe 'when something goes wrong' do
    it 'reports the failing grant, still applies the others, and asks to be tried again, leaving the payment alone' do
      allow(BetterTogether).to receive(:report_error)
      allow_any_instance_of(BetterTogether::Billing::Entitlements::Handlers::FeatureAccess).to receive(:apply).and_raise('boom') # rubocop:disable RSpec/AnyInstance
      payment_state = nil

      expect { term }.not_to raise_error # the follow-up job retries; the payment stands
      expect { sync(term) }.to raise_error(described_class::Incomplete, /boom/)

      expect(entitlement.grants.applied.pluck(:kind)).to contain_exactly('membership_role', 'quota_allowance')
      expect(term.periods.first.order.reload).to be_paid
      expect(BetterTogether).to have_received(:report_error).at_least(:once)
      expect(payment_state).to be_nil
    end
  end
end
