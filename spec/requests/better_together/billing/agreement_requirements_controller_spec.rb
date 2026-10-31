# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::AgreementRequirementsController do
  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:steward) { find_or_create_test_user("req-steward-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:member) { find_or_create_test_user("req-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:other_platform) { create(:better_together_platform) }
  let!(:agreement) do
    create(:better_together_agreement, agreement_kind: 'transactional_agreement', platform: host_platform, identifier: 'extra-terms')
  end

  def path = better_together.billing_agreement_requirements_path(locale:)

  def params_for(**attrs)
    { billing_agreement_requirement: { agreement_id: agreement.id, mode: 'additional' }.merge(attrs) }
  end

  it 'sends a visitor to sign in' do
    get path

    expect(response).to have_http_status(:found)
  end

  it 'turns a signed-in non-steward away' do
    sign_in member

    get path

    expect(response).to have_http_status(:found)
    expect(response.body).not_to include('billing-agreement-requirements-page')
  end

  it 'is a 404 while billing is not switched on for the host' do
    sign_in steward
    allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

    get path

    expect(response).to have_http_status(:not_found)
  end

  context 'when signed in as a steward' do
    before { sign_in steward }

    it 'lists the requirements with the state of each agreement, and the checklist' do
      BetterTogether::Billing::PurchaseAgreementSeeds.call(host_platform)

      get path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-agreement-requirements-page', 'billing-agreement-requirements-table',
                                       'billing-readiness-checklist',
                                       'billing-agreement-requirement-form', 'billing-requirement-agreement', 'billing-requirement-plan',
                                       'billing-requirement-purpose', 'billing-requirement-method', 'billing-requirement-mode',
                                       'billing-requirement-add-btn',
                                       'billing-agreement-state-badge')
    end

    it 'says so when there are none' do
      host_platform.billing_agreement_requirements.destroy_all

      get path

      expect(response.body).to include('billing-agreement-requirements-empty')
    end

    it 'offers only this platform\'s purchase agreements' do
      create(:better_together_agreement, agreement_kind: 'transactional_agreement', platform: other_platform, identifier: 'foreign-terms')
      create(:better_together_agreement, agreement_kind: 'policy_consent', platform: host_platform, identifier: 'plain-policy')

      get path

      expect(response.body).to include(agreement.title)
      expect(response.body).not_to include('foreign-terms', 'plain-policy')
    end

    it 'adds a requirement for a plan, a purpose and a method' do
      expect do
        post path, params: params_for(target_plan_id: plan.id, purpose: 'ticket', payment_method: 'cash')
      end.to change(host_platform.billing_agreement_requirements, :count).by(1)

      expect(response).to redirect_to(path)
      expect(host_platform.billing_agreement_requirements.find_by(agreement:)).to have_attributes(target: plan, purpose: 'ticket',
                                                                                                  payment_method: 'cash')
    end

    it 'adds a platform default when no plan is chosen' do
      post path, params: params_for(target_plan_id: '')

      expect(host_platform.billing_agreement_requirements.find_by(agreement:)).to be_platform_default
    end

    it 're-renders with errors for a mistake' do
      post path, params: params_for(purpose: 'barter')

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('billing-agreement-requirement-errors')
    end

    it 'ignores another platform\'s agreement, plan, and a crafted platform or target type' do
      foreign_agreement = create(:better_together_agreement, agreement_kind: 'transactional_agreement', platform: other_platform,
                                                             identifier: 'foreign-3')
      foreign_plan = create(:better_together_billing_plan, platform: other_platform)

      post path, params: params_for(agreement_id: foreign_agreement.id)
      expect(response).to have_http_status(:unprocessable_content)

      post path, params: params_for(target_plan_id: foreign_plan.id, platform_id: other_platform.id, target_type: 'Kernel')
      expect(host_platform.billing_agreement_requirements.find_by(agreement:)).to be_platform_default
      expect(other_platform.billing_agreement_requirements).to be_empty
    end

    it 'removes a requirement' do
      requirement = host_platform.billing_agreement_requirements.create!(agreement:, mode: 'additional')

      expect { delete better_together.billing_agreement_requirement_path(requirement, locale:) }
        .to change(host_platform.billing_agreement_requirements, :count).by(-1)
      expect(response).to redirect_to(path)
    end

    it 'cannot remove another platform\'s requirement' do
      foreign_agreement = create(:better_together_agreement, agreement_kind: 'transactional_agreement', platform: other_platform,
                                                             identifier: 'foreign-4')
      foreign = other_platform.billing_agreement_requirements.create!(agreement: foreign_agreement, mode: 'additional')

      delete better_together.billing_agreement_requirement_path(foreign, locale:)

      expect(response).to have_http_status(:not_found)
      expect(foreign.reload).to be_persisted
    end
  end

  it 'lets a member change nothing' do
    sign_in member

    expect { post path, params: params_for }.not_to change(BetterTogether::Billing::AgreementRequirement, :count)
  end
end
