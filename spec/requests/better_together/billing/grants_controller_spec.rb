# frozen_string_literal: true

require 'rails_helper'

# A steward chooses what a plan includes.
RSpec.describe BetterTogether::Billing::GrantsController do
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }

  def grants_path(plan = sub_plan) = better_together.billing_product_grants_path(plan, locale:)
  def grant_path(grant, plan = sub_plan) = better_together.billing_product_grant_path(plan, grant, locale:)
  def plan_path(plan = sub_plan) = better_together.billing_plan_path(plan, locale:)

  it 'sends a visitor to sign in' do
    post grants_path, params: { kind: 'feature_access', feature_key: 'device_permissions', access_level: 'beta' }

    expect(response).to have_http_status(:found)
    expect(sub_plan.grants).to be_empty
  end

  it 'turns a member away' do
    sign_in buyer_user

    post grants_path, params: { kind: 'feature_access', feature_key: 'device_permissions', access_level: 'beta' }

    expect(sub_plan.grants.reload).to be_empty
  end

  context 'when signed in as a steward' do
    before { sign_in steward_user }

    it 'shows what the plan includes, and the forms to add to it' do
      role_grant
      get plan_path

      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(sub_plan, :grants), 'billing-grant-role-form',
                                       'billing-grant-feature-form',
                                       'billing-grant-storage-form', ActionView::RecordIdentifier.dom_id(sub_plan.grants.first))
    end

    it 'asks before every change to what a plan includes, saying how many people it reaches', :aggregate_failures do
      start_subscription
      get plan_path

      expect(response.body.scan('data-turbo-confirm').size).to be >= 3
      expect(response.body).to include("(#{BetterTogether::Billing::PlanAudience.new(sub_plan).count})")
    end

    it 'changes the amount of a storage grant in place, and brings the subscribers up to date', :aggregate_failures do
      grant = add_grant('quota_allowance', { 'quota_type' => 'media_storage', 'amount' => 1_000_000_000 })
      patch "#{grants_path}/#{grant.id}", params: { amount: '5000000000' }

      expect(grant.reload.parameters['amount'].to_i).to eq(5_000_000_000)
      expect(BetterTogether::Billing::SyncPlanEntitlementsJob).to have_been_enqueued.with(sub_plan)
    end

    it 'refuses a second grant of the same thing, and a bad amount on an edit', :aggregate_failures do
      grant = add_grant('quota_allowance', { 'quota_type' => 'media_storage', 'amount' => 1_000_000_000 })

      expect { post grants_path, params: { kind: 'quota_allowance', quota_type: 'media_storage', amount: '2000000000' } }
        .not_to(change { sub_plan.grants.count })
      patch "#{grants_path}/#{grant.id}", params: { amount: '-1' }
      expect(grant.reload.parameters['amount'].to_i).to eq(1_000_000_000)
    end

    it 'adds a role, then queues the plan\'s people to be brought up to date' do
      expect do
        post grants_path, params: { kind: 'membership_role', joinable: 'platform', role: supporter_role.identifier }
      end.to have_enqueued_job(BetterTogether::Billing::SyncPlanEntitlementsJob).with(sub_plan)

      expect(response).to redirect_to_billing_screen(plan_path)
      expect(sub_plan.grants.sole).to have_attributes(kind: 'membership_role',
                                                      parameters: {
                                                        'joinable' => 'platform', 'role' => supporter_role.identifier
                                                      })
    end

    it 'offers storage as the same sizes the platform quota form does, in bytes', :aggregate_failures do
      get plan_path

      expect(response.body).to include('id="billing-grant-storage-amount"', '>5 GB</option>', 'value="5000000000"')
      expect(response.body).not_to include('billing-grant-storage-unit')
    end

    it 'adds feature access and a quota allowance' do
      post grants_path, params: { kind: 'feature_access', feature_key: 'device_permissions', access_level: 'beta' }
      post grants_path, params: { kind: 'quota_allowance', quota_type: 'media_storage', amount: '1000' }

      expect(sub_plan.grants.reload.pluck(:kind)).to eq(%w[feature_access quota_allowance])
    end

    it 'refuses a role that can manage things, an unknown feature, a bad amount and a kind that is not on the list' do
      [{ kind: 'membership_role', joinable: 'platform', role: manager_role.identifier },
       { kind: 'feature_access', feature_key: 'nonsense', access_level: 'beta' },
       { kind: 'quota_allowance', quota_type: 'media_storage', amount: '-5' },
       { kind: 'root_access', anything: 'goes' }].each do |bad|
        post grants_path, params: bad

        expect(flash[:alert]).to eq(I18n.t('better_together.billing.grants.refused'))
      end
      expect(sub_plan.grants.reload).to be_empty
    end

    it 'ignores parameters a kind does not declare' do
      post grants_path, params: { kind: 'feature_access', feature_key: 'device_permissions', access_level: 'beta', admin: 'true' }

      expect(sub_plan.grants.sole.parameters.keys).to contain_exactly('feature_key', 'access_level')
    end

    it 'removes one and queues the plan\'s people to be brought up to date' do
      grant = role_grant

      expect { delete grant_path(grant) }.to have_enqueued_job(BetterTogether::Billing::SyncPlanEntitlementsJob)

      expect(sub_plan.grants.reload).to be_empty
    end

    it 'is a 404 for another platform\'s plan or a seller\'s plan' do
      other = create(:better_together_platform)
      foreign = create(:better_together_billing_plan, platform: other)

      post grants_path(foreign), params: { kind: 'feature_access', feature_key: 'device_permissions', access_level: 'beta' }

      expect(response).to have_http_status(:not_found)
    end

    it 'cannot remove a grant of another plan through this plan\'s address' do
      other_plan = create(:better_together_billing_plan, processor: nil, processor_price_id: nil, accepted_payment_methods: %w[cash])
      grant = add_grant('feature_access', { 'feature_key' => 'device_permissions', 'access_level' => 'beta' }, plan: other_plan)

      delete grant_path(grant, sub_plan)

      expect(response).to have_http_status(:not_found)
      expect(other_plan.grants.reload).to be_present
    end
  end
end
