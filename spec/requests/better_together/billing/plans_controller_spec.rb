# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::PlansController do
  include_context 'with clean billing processors'

  let(:locale) { :en }
  let(:platform_manager) do
    find_or_create_test_user(
      "billing-plans-manager-#{SecureRandom.hex(4)}@example.test",
      'SecureTest123!@#',
      :platform_manager
    )
  end
  let(:regular_user) do
    find_or_create_test_user(
      "billing-plans-regular-#{SecureRandom.hex(4)}@example.test",
      'SecureTest123!@#'
    )
  end
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[checkout plan_sync]) }
  let!(:billing_plan) do
    BetterTogether::Billing.register_processor(:fake, -> { adapter })
    create(:better_together_billing_plan)
  end

  describe 'GET /:locale/host/billing/plans' do
    context 'as platform manager' do
      before { sign_in platform_manager }

      it 'returns 200 and lists plans' do
        get better_together.billing_plans_path(locale:)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(billing_plan.name)
      end
    end

    context 'as regular user' do
      before { sign_in regular_user }

      it 'returns 404 (route constraint blocks non-stewards)' do
        get better_together.billing_plans_path(locale:)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'as unauthenticated user' do
      it 'returns 404 (route constraint blocks unauthenticated access)' do
        get better_together.billing_plans_path(locale:)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /:locale/host/billing/plans/new' do
    before { sign_in platform_manager }

    it 'returns 200 and offers only installed processors' do
      get better_together.new_billing_plan_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<option value="fake">fake</option>')
      expect(response.body).not_to include('Stripe')
    end
  end

  describe 'POST /:locale/host/billing/plans' do
    before { sign_in platform_manager }

    let(:valid_params) do
      {
        billing_plan: {
          identifier: "test-plan-#{SecureRandom.hex(4)}",
          name: 'Test Plan',
          description: 'A test plan',
          billing_interval: 'month',
          amount_cents: 4500,
          currency: 'USD',
          processor: 'fake',
          processor_price_id: "price_#{SecureRandom.hex(8)}",
          active: true,
          metadata: {
            participant_summary: 'Test summary',
            participant_benefits: ['Benefit one', 'Benefit two'],
            beneficiary_label: 'Hosted access',
            hosted_access_level: 'Standard',
            support_tier: 'Community',
            community_capacity_tier: '',
            eligible_billable_owner_types: ['BetterTogether::Community']
          }
        }
      }
    end

    it 'creates a plan and redirects to show' do
      expect do
        post better_together.billing_plans_path(locale:), params: valid_params
      end.to change(BetterTogether::Billing::Plan, :count).by(1)

      new_plan = BetterTogether::Billing::Plan.last
      expect(response).to redirect_to(better_together.billing_plan_path(new_plan, locale:))
      expect(flash[:notice]).to include('created')
    end

    it 're-renders new with 422 on invalid params' do
      post better_together.billing_plans_path(locale:),
           params: { billing_plan: { identifier: '', name: '', processor_price_id: '' } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a currency code outside the supported list' do
      expect do
        post better_together.billing_plans_path(locale:),
             params: valid_params.deep_merge(billing_plan: { currency: 'ZZZ' })
      end.not_to change(BetterTogether::Billing::Plan, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a price the processor does not know' do
      expect do
        post better_together.billing_plans_path(locale:),
             params: valid_params.deep_merge(billing_plan: { processor_price_id: 'price_missing_x' })
      end.not_to change(BetterTogether::Billing::Plan, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a processor that is not installed' do
      expect do
        post better_together.billing_plans_path(locale:),
             params: valid_params.deep_merge(billing_plan: { processor: 'ghost' })
      end.not_to change(BetterTogether::Billing::Plan, :count)
    end
  end

  describe 'GET /:locale/host/billing/plans/:id' do
    before { sign_in platform_manager }

    it 'returns 200 and shows plan details' do
      get better_together.billing_plan_path(billing_plan, locale:)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(billing_plan.name)
      expect(response.body).to include(billing_plan.identifier)
    end
  end

  describe 'GET /:locale/host/billing/plans/:id/edit' do
    before { sign_in platform_manager }

    it 'returns 200' do
      get better_together.edit_billing_plan_path(billing_plan, locale:)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /:locale/host/billing/plans/:id' do
    before { sign_in platform_manager }

    it 'updates name and redirects to show' do
      patch better_together.billing_plan_path(billing_plan, locale:),
            params: { billing_plan: { name: 'Updated Name' } }

      expect(response).to redirect_to(better_together.billing_plan_path(billing_plan, locale:))
      expect(billing_plan.reload.name).to eq('Updated Name')
    end

    it 'deactivates plan via active: false' do
      billing_plan.update!(active: true)

      patch better_together.billing_plan_path(billing_plan, locale:),
            params: { billing_plan: { active: false } }

      expect(billing_plan.reload.active).to be(false)
    end
  end
end
