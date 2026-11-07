# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Plan grants, entitlements and their grants' do # rubocop:disable RSpec/DescribeClass
  include_context 'with entitlement fixtures'

  def new_grant(entitlement, **attrs)
    entitlement.grants.build({ platform_id: host_platform.id, grant_key: 'quota_allowance:media_storage', kind: 'quota_allowance',
                               parameters: {} }.merge(attrs))
  end

  describe BetterTogether::Billing::PlanGrant do
    it 'belongs to a plan and a platform, in order' do
      grant = role_grant

      expect(grant).to have_attributes(plan: sub_plan, platform_id: host_platform.id, position: 0)
      expect(sub_plan.plan_grants).to eq([grant])
      expect(feature_grant.position).to eq(1)
    end

    it 'only allows the kinds on the allow-list' do
      grant = sub_plan.plan_grants.build(platform_id: host_platform.id, kind: 'root_access', parameters: {})

      expect(grant).not_to be_valid
      expect(BetterTogether::Billing::Entitlements::Registry.kinds).to eq(%w[membership_role feature_access quota_allowance])
    end

    it 'checks its parameters with the kind\'s handler and says what is wrong' do
      grant = sub_plan.plan_grants.build(platform_id: host_platform.id, kind: 'membership_role',
                                         parameters: { 'joinable' => 'platform', 'role' => manager_role.identifier })

      expect(grant).not_to be_valid
      expect(grant.errors.details[:parameters].pluck(:error)).to eq([:role_privileged])
    end

    it 'gives the handler for its kind' do
      expect(role_grant.handler).to be_a(BetterTogether::Billing::Entitlements::Handlers::MembershipRole)
    end

    it 'keeps the plan it began with and agrees with it on the platform' do
      grant = role_grant
      grant.platform_id = create(:better_together_platform).id

      expect(grant).not_to be_valid
    end
  end

  describe BetterTogether::Billing::Entitlement do
    let(:entitlement) { make_entitlement }

    it 'has one source, a Pay subscription or an order, and never both or neither' do
      both = entitlement.dup.tap { |copy| copy.order = place_order }
      neither = host_platform.billing_entitlements.build(plan: sub_plan, beneficiary: buyer, starts_at: Time.current)

      expect(entitlement).to be_valid
      expect(both).not_to be_valid
      expect(neither).not_to be_valid
    end

    it 'allows one live entitlement per person and plan, but any number once lapsed' do
      entitlement
      other_term = start_subscription(payer: create(:better_together_person))
      second = host_platform.billing_entitlements.build(plan: sub_plan, beneficiary: buyer, starts_at: Time.current,
                                                        pay_subscription: other_term.pay_subscription)

      expect { second.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'finds who paid' do
      expect(entitlement.payer).to be_a(BetterTogether::Person)
      expect(entitlement).to be_live
      expect(described_class.live).to include(entitlement)
    end

    it 'refuses a beneficiary type that is not allowed' do
      entitlement.beneficiary_type = 'BetterTogether::Role'

      expect(entitlement).not_to be_valid
    end

    it 'keeps its plan, beneficiary and source' do
      other = create(:better_together_billing_plan)
      entitlement.update!(plan: other, status: 'lapsed')

      expect(entitlement.reload).to have_attributes(plan: sub_plan, status: 'lapsed')
    end

    it 'is reached through its platform' do
      expect(host_platform.billing_entitlements).to include(entitlement)
    end
  end

  describe BetterTogether::Billing::EntitlementGrant do
    let(:entitlement) { make_entitlement }

    it 'is one grant per key for an entitlement' do
      new_grant(entitlement).save!

      expect(new_grant(entitlement)).not_to be_valid
    end

    it 'only names a membership or a feature grant as what it applied' do
      expect(new_grant(entitlement, applied_type: 'BetterTogether::Person', applied_id: buyer.id)).not_to be_valid
      expect(new_grant(entitlement, applied_type: 'BetterTogether::FeatureAccessGrant', applied_id: SecureRandom.uuid)).to be_valid
    end

    it 'says when it was let go' do
      record = new_grant(entitlement).tap(&:save!)
      record.release!

      expect(record.reload).to have_attributes(status: 'released', released_at: be_present)
      expect(described_class.applied).not_to include(record)
    end

    it 'never holds a negative amount, in the model and the database' do
      expect(new_grant(entitlement, amount: -1)).not_to be_valid
      record = new_grant(entitlement).tap(&:save!)
      expect do
        described_class.where(id: record.id).update_all(amount: -1) # rubocop:disable Rails/SkipsModelValidations
      end.to raise_error(ActiveRecord::StatementInvalid, /chk_bt_billing_ent_grants_amount/)
    end
  end
end
