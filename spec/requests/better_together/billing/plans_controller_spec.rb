# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::PlansController do
  include ActiveJob::TestHelper

  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:platform_manager) { find_or_create_test_user("billing-plans-manager-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:regular_user) { find_or_create_test_user("billing-plans-regular-#{SecureRandom.hex(4)}@example.test", password) }
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[checkout plan_sync lookups]) }
  let(:other_platform) { create(:better_together_platform) }
  let!(:billing_plan) do
    BetterTogether::Billing.register_processor(:fake, -> { adapter })
    create(:better_together_billing_plan)
  end
  # Another platform's plan. It could not be created through the model (that platform has
  # no processor), which is the point; it is written directly.
  let(:foreign_plan) do
    build(:better_together_billing_plan, platform: other_platform).tap { |plan| plan.save!(validate: false) }
  end

  def plans_path(**) = better_together.billing_plans_path(locale:, **)
  def plan_path(plan) = better_together.billing_plan_path(plan, locale:)

  describe 'who may reach the plans' do
    it 'sends a visitor to sign in' do
      get plans_path

      expect(response).to have_http_status(:found)
      expect(response.location).to include('sign-in').or include('users/sign_in')
    end

    it 'turns a signed-in non-steward away without listing anything' do
      sign_in regular_user

      get plans_path

      expect(response).to have_http_status(:found)
      expect(response.body).not_to include(billing_plan.name)
    end

    it 'is a 404 for everyone while billing is off, before sign-in is asked for' do
      allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

      get plans_path

      expect(response).to have_http_status(:not_found)
    end

    it 'is a 404 for a steward when the platform has no processor configured' do
      sign_in platform_manager
      BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)

      get plans_path

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'plans sold by a community' do
    let(:community) { create(:better_together_community) }
    let!(:seller_plan) do
      BetterTogether::Billing::Billable.model_names << 'BetterTogether::Community'
      create(:better_together_billing_plan, seller: community, name: 'Community seller secret')
    end

    before { sign_in platform_manager }

    it 'are not listed among the platform\'s plans' do
      get plans_path

      expect(response.body).not_to include('Community seller secret')
    end

    it 'are not reachable through the platform screens' do
      get plan_path(seller_plan)
      expect(response).to have_http_status(:not_found)

      patch plan_path(seller_plan), params: { billing_plan: { name: 'Hijacked' } }
      expect(response).to have_http_status(:not_found)
      expect(seller_plan.reload.name).to eq('Community seller secret')
    end

    it 'are not created by the platform form, whatever seller is sent' do
      post plans_path, params: { billing_plan: { identifier: 'x', name: 'X', processor: 'fake', amount_cents: 1, currency: 'USD',
                                                 seller_type: 'BetterTogether::Community', seller_id: community.id } }

      expect(BetterTogether::Billing::Plan.sold_by(community).where(identifier: 'x')).to be_empty
    end
  end

  describe 'paying some way other than the online processor' do
    let(:cash) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[offline_settlement], processor: :cash, settlement: :manual) }

    before do
      sign_in platform_manager
      BetterTogether::Billing.register_processor(:cash, -> { cash })
    end

    it 'offers the installed non-vendor methods as check boxes, and keeps them out of the processor list' do
      get better_together.new_billing_plan_path(locale:)

      expect(response.body).to include('billing-plan-payment-methods', 'billing-plan-payment-method-cash')
      expect(response.body).not_to include('<option value="cash">')
    end

    it 'saves the accepted methods with the plan' do
      post plans_path, params: { billing_plan: { identifier: 'with-cash', name: 'With cash', processor: 'fake', amount_cents: 4500,
                                                 currency: 'USD', accepted_payment_methods: ['', 'cash'] } }

      expect(BetterTogether::Billing::Plan.find_by(identifier: 'with-cash').accepted_payment_methods).to eq(%w[cash])
    end

    it 'creates a plan that is paid only by an accepted method, with no online processor' do
      expect do
        post plans_path, params: { billing_plan: { identifier: 'cash-only', name: 'Cash only', processor: '', amount_cents: 2000,
                                                   currency: 'CAD', accepted_payment_methods: ['cash'] } }
      end.not_to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)

      expect(BetterTogether::Billing::Plan.find_by(identifier: 'cash-only')).to have_attributes(processor: nil, sync_status: 'synced')
    end

    it 'refuses a plan nobody could pay for' do
      expect do
        post plans_path, params: { billing_plan: { identifier: 'nothing', name: 'Nothing', processor: '', amount_cents: 1, currency: 'USD' } }
      end.not_to change(BetterTogether::Billing::Plan, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'lets the accepted methods change on a linked plan, whose price is locked' do
      patch plan_path(billing_plan), params: { billing_plan: { accepted_payment_methods: %w[cash], amount_cents: 1 } }

      expect(billing_plan.reload).to have_attributes(accepted_payment_methods: %w[cash])
      expect(billing_plan.amount_cents).not_to eq(1)
    end

    it 'shows the accepted methods on the plan page' do
      billing_plan.update!(accepted_payment_methods: %w[cash])

      get plan_path(billing_plan)

      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(billing_plan, :payment_methods))
    end

    it 'shows a plan with no online processor' do
      plan = create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash])

      get plan_path(plan)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('better_together.billing.plans.processor_none'))
    end
  end

  describe 'GET /:locale/billing/plans' do
    before { sign_in platform_manager }

    it 'lists the plans of the platform' do
      get plans_path

      expect(response).to have_http_status(:ok)
      expect_html_content(billing_plan.name)
      expect(response.body).to include('billing-plans-table')
    end

    it 'does not list another platform\'s plans' do
      foreign_plan.update_columns(name: 'Other tenant secret') # rubocop:disable Rails/SkipsModelValidations

      get plans_path

      expect(response.body).not_to include('Other tenant secret')
    end
  end

  describe 'GET /:locale/billing/plans/new' do
    before { sign_in platform_manager }

    it 'offers only installed processors' do
      get better_together.new_billing_plan_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<option value="fake">fake</option>')
      expect(response.body).not_to include('Stripe')
    end

    it 'offers the create-in-processor and link-existing modes' do
      get better_together.new_billing_plan_path(locale:)

      expect(response.body).to include('billing-plan-mode-tabs')
    end

    it 'shows the price picker when asked to link an existing price' do
      get better_together.new_billing_plan_path(locale:, mode: 'link')

      expect(response.body).to include('billing-plan-price-select')
    end

    it 'starts a changed price from the old plan, sharing its product' do
      get better_together.new_billing_plan_path(locale:, from: billing_plan.id)

      expect(response.body).to include("#{billing_plan.identifier}-next")
    end

    it 'ignores a "from" plan of another platform' do
      get better_together.new_billing_plan_path(locale:, from: foreign_plan.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("#{foreign_plan.identifier}-next")
    end
  end

  describe 'POST /:locale/billing/plans' do
    before { sign_in platform_manager }

    let(:benefits) { ['Benefit one', 'Benefit two'] }
    let(:valid_params) do
      { billing_plan: { identifier: "test-plan-#{SecureRandom.hex(4)}", name: 'Test Plan', description: 'A test plan',
                        billing_interval: 'month', amount_cents: 4500, currency: 'USD', processor: 'fake', active: true,
                        metadata: { participant_summary: 'Test summary', participant_benefits: [benefits.join("\n")],
                                    beneficiary_label: 'Hosted access', hosted_access_level: 'Standard',
                                    support_tier: 'Community', community_capacity_tier: '',
                                    eligible_billable_owner_types: ['', 'BetterTogether::Community'] } } }
    end

    it 'creates a plan for the processor to push, and redirects to it' do
      expect do
        post plans_path, params: valid_params
      end.to change(BetterTogether::Billing::Plan, :count).by(1).and have_enqueued_job(BetterTogether::Billing::SyncPlanJob)

      plan = BetterTogether::Billing::Plan.order(:created_at).last
      expect(response).to redirect_to(plan_path(plan))
      expect(plan).to have_attributes(platform: Current.platform || BetterTogether::Platform.find_by(host: true), sync_status: 'pending',
                                      processor_price_id: nil)
    end

    it 'stores one benefit per line and drops blank owner types' do
      post plans_path, params: valid_params

      metadata = BetterTogether::Billing::Plan.order(:created_at).last.metadata
      expect(metadata['participant_benefits']).to eq(benefits)
      expect(metadata['eligible_billable_owner_types']).to eq(['BetterTogether::Community'])
    end

    it 'links an existing price, copying its amount from the processor, not the form' do
      adapter.prices['price_yearly'] = BetterTogether::Billing::PriceInfo.new(
        price_id: 'price_yearly', product_id: 'prod_pro', amount_cents: 99_000, currency: 'USD', interval: 'year'
      )

      expect do
        post plans_path, params: valid_params.deep_merge(billing_plan: { link_existing: '1', processor_price_id: 'price_yearly' })
      end.not_to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)

      expect(BetterTogether::Billing::Plan.find_by(processor_price_id: 'price_yearly'))
        .to have_attributes(amount_cents: 99_000, billing_interval: 'year', processor_product_id: 'prod_pro', sync_status: 'synced')
    end

    it 'puts the plan on the current platform whatever platform_id is sent' do
      post plans_path, params: valid_params.deep_merge(billing_plan: { platform_id: other_platform.id })

      expect(BetterTogether::Billing::Plan.where(platform_id: other_platform.id)).to be_empty
    end

    it 're-renders new with 422 on invalid params' do
      post plans_path, params: { billing_plan: { identifier: '', name: '' } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a currency code outside the supported list' do
      expect do
        post plans_path, params: valid_params.deep_merge(billing_plan: { currency: 'ZZZ' })
      end.not_to change(BetterTogether::Billing::Plan, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a price the processor does not know' do
      expect do
        post plans_path, params: valid_params.deep_merge(billing_plan: { link_existing: '1', processor_price_id: 'price_missing_x' })
      end.not_to change(BetterTogether::Billing::Plan, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a processor that is not installed' do
      expect do
        post plans_path, params: valid_params.deep_merge(billing_plan: { processor: 'ghost' })
      end.not_to change(BetterTogether::Billing::Plan, :count)
    end

    it 'rejects an owner type that has not opted in to billing' do
      expect do
        post plans_path, params: valid_params.deep_merge(billing_plan: { metadata: { eligible_billable_owner_types: ['Kernel'] } })
      end.not_to change(BetterTogether::Billing::Plan, :count)
    end
  end

  describe 'GET /:locale/billing/plans/:id' do
    before { sign_in platform_manager }

    it 'shows the plan with the fields the processor has fixed' do
      get plan_path(billing_plan)

      expect(response).to have_http_status(:ok)
      expect_html_contents(billing_plan.name, billing_plan.identifier)
      expect(response.body).to include('billing-plan-locked-fields-note')
      expect(response.body).to include('billing-plan-processor-snapshot')
    end

    it 'offers a retry for a plan whose push failed' do
      billing_plan.record_sync_failure!('processor_unavailable')

      get plan_path(billing_plan)

      expect(response.body).to include('billing-plan-retry-sync-btn')
    end

    it 'offers no retry for a synced plan' do
      get plan_path(billing_plan)

      expect(response.body).not_to include('billing-plan-retry-sync-btn')
    end

    it 'is a 404 for another platform\'s plan' do
      get plan_path(foreign_plan)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /:locale/billing/plans/:id/edit' do
    before { sign_in platform_manager }

    it 'returns 200 and shows the fixed fields as text, not inputs' do
      get better_together.edit_billing_plan_path(billing_plan, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('name="billing_plan[amount_cents]"')
    end

    it 'is a 404 for another platform\'s plan' do
      get better_together.edit_billing_plan_path(foreign_plan, locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /:locale/billing/plans/:id' do
    before { sign_in platform_manager }

    it 'updates the name and redirects to show' do
      patch plan_path(billing_plan), params: { billing_plan: { name: 'Updated Name' } }

      expect(response).to redirect_to(plan_path(billing_plan))
      expect(billing_plan.reload.name).to eq('Updated Name')
    end

    it 'deactivates the plan' do
      patch plan_path(billing_plan), params: { billing_plan: { active: false } }

      expect(billing_plan.reload.active).to be(false)
    end

    it 'ignores crafted attempts to change what the processor fixed at creation' do
      original = billing_plan.slice(:amount_cents, :currency, :billing_interval, :processor_price_id, :processor_product_id, :processor)

      patch plan_path(billing_plan), params: { billing_plan: {
        name: 'Renamed', amount_cents: 1, currency: 'CAD', billing_interval: 'year', processor_price_id: 'price_other',
        processor_product_id: 'prod_other', processor: 'ghost', platform_id: other_platform.id
      } }

      expect(billing_plan.reload.slice(*original.keys)).to eq(original)
      expect(billing_plan).to have_attributes(name: 'Renamed', platform_id: BetterTogether::Platform.find_by(host: true).id)
    end

    it 'merges metadata, keeping keys the form does not carry' do
      billing_plan.update!(metadata: billing_plan.metadata.merge('written_by_a_later_feature' => 'keep me'))

      patch plan_path(billing_plan), params: { billing_plan: { metadata: { support_tier: 'Premium' } } }

      expect(billing_plan.reload.metadata).to include('support_tier' => 'Premium', 'written_by_a_later_feature' => 'keep me',
                                                      'hosted_access_level' => 'Standard')
    end

    it 'cannot update another platform\'s plan' do
      patch plan_path(foreign_plan), params: { billing_plan: { name: 'Hijacked' } }

      expect(response).to have_http_status(:not_found)
      expect(foreign_plan.reload.name).not_to eq('Hijacked')
    end
  end

  describe 'a signed-in non-steward' do
    before { sign_in regular_user }

    it 'cannot create a plan' do
      expect do
        post plans_path, params: { billing_plan: { identifier: 'x', name: 'X', processor: 'fake', amount_cents: 1, currency: 'USD' } }
      end.not_to change(BetterTogether::Billing::Plan, :count)
    end

    it 'cannot update a plan' do
      patch plan_path(billing_plan), params: { billing_plan: { name: 'Nope' } }

      expect(billing_plan.reload.name).not_to eq('Nope')
    end

    it 'cannot restart a sync' do
      billing_plan.record_sync_failure!('processor_error')

      expect { post better_together.sync_billing_plan_path(billing_plan, locale:) }.not_to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)
    end
  end

  describe 'POST /:locale/billing/plans/:id/sync' do
    before { sign_in platform_manager }

    let(:sync_path) { better_together.sync_billing_plan_path(billing_plan, locale:) }

    it 'restarts a failed push' do
      billing_plan.record_sync_failure!('processor_unavailable')

      expect { post sync_path }.to have_enqueued_job(BetterTogether::Billing::SyncPlanJob).with(billing_plan.id)

      expect(billing_plan.reload).to have_attributes(sync_status: 'pending', sync_error: nil)
      expect(response).to redirect_to(plan_path(billing_plan))
    end

    it 'says so when the processor cannot push plans' do
      BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)
      BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })

      expect { post sync_path }.not_to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)
      expect(flash[:alert]).to be_present
    end

    it 'is a 404 for another platform\'s plan' do
      expect { post better_together.sync_billing_plan_path(foreign_plan, locale:) }
        .not_to have_enqueued_job(BetterTogether::Billing::SyncPlanJob)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /:locale/billing/plans/:id/snapshot' do
    before { sign_in platform_manager }

    it 'shows what the processor holds for the plan' do
      get better_together.snapshot_billing_plan_path(billing_plan, locale:)

      expect(response).to have_http_status(:ok)
      expect(adapter.calls.map(&:first)).to include(:fetch_price)
    end

    it 'is a 404 for another platform\'s plan, and asks the processor nothing' do
      get better_together.snapshot_billing_plan_path(foreign_plan, locale:)

      expect(response).to have_http_status(:not_found)
      expect(adapter.calls).to be_empty
    end
  end
end
