# frozen_string_literal: true

# rubocop:disable Layout/LineLength
require 'rails_helper'

RSpec.describe 'Billing foundation DOM contracts', :skip_host_setup, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:host_platform) { configure_host_platform }
  let!(:platform_manager) { BetterTogether::User.find_by!(email: 'manager@example.test') }
  let!(:community) { create(:better_together_community, name: 'Harbour Voices') }
  let!(:plan) do
    create(
      :better_together_billing_plan,
      identifier: 'harbour-stewardship',
      name: 'Harbour Stewardship',
      metadata: {
        'participant_summary' => 'Keeps the hosted community available and stewarded.',
        'participant_benefits' => ['Hosted community access', 'Steward support'],
        'beneficiary_label' => 'Community access',
        'hosted_access_level' => 'Partner',
        'support_tier' => 'Priority',
        'community_capacity_tier' => 'Growth'
      }
    )
  end

  let!(:solidarity_plan) do
    create(
      :better_together_billing_plan,
      identifier: 'harbour-solidarity',
      name: 'Harbour Solidarity',
      amount_cents: 2_500,
      stripe_price_id: 'price_test_harbour_solidarity',
      metadata: {
        'participant_summary' => 'A reduced-contribution option for smaller co-ops.',
        'beneficiary_label' => 'Community access',
        'pricing_tier' => 'solidarity_small',
        'solidarity_description' => 'For co-ops with fewer than 20 members.'
      }
    )
  end

  before do
    Current.platform = host_platform
  end

  after do
    Current.platform = nil
  end

  it 'community billing page exposes stable review anchors' do
    create(:better_together_billing_subscription, billing_plan: plan, billable_owner: community, beneficiary: community)
    capybara_login_as_platform_manager

    visit better_together.community_billing_path(community, locale: I18n.default_locale)

    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(community, :billing_page)}")
    expect(page).to have_css('#hosted-entitlement-card')
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(community, :current_subscription_card)}")
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(community, :merchant_account_card)}")
    expect(page).to have_css('#community-billing-plans-table')
    expect(page).to have_css('.billing-plan-solidarity-badge', text: 'Solidarity — Small')
  end

  it 'person billing page exposes stable review anchors' do
    create(:better_together_billing_subscription, billing_plan: plan, billable_owner: platform_manager.person,
                                                  beneficiary: platform_manager.person)
    capybara_login_as_platform_manager

    visit better_together.person_billing_path(platform_manager.person, locale: I18n.default_locale)

    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(platform_manager.person, :billing_page)}")
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(platform_manager.person, :current_subscription_card)}")
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(platform_manager.person, :merchant_account_card)}")
    expect(page).to have_css('#person-billing-plans-table')
    expect(page).to have_css('.billing-plan-solidarity-badge', text: 'Solidarity — Small')
  end

  it 'plan index exposes stable review anchors' do
    capybara_login_as_platform_manager

    visit better_together.billing_plans_path(locale: I18n.default_locale)

    expect(page).to have_css('#billing-plans-index-page')
    expect(page).to have_css('#new-billing-plan-btn')
    expect(page).to have_css('#billing-plans-table')
    expect(page).to have_css('.billing-plan-status-badge')
  end

  it 'plan show exposes stable review anchors' do
    capybara_login_as_platform_manager

    visit better_together.billing_plan_path(plan, locale: I18n.default_locale)

    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(plan, :show_page)}")
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(plan, :summary_details)}")
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(plan, :metadata_details)}")
  end

  it 'solidarity-tier plan show exposes pricing tier and solidarity description anchors' do
    capybara_login_as_platform_manager

    visit better_together.billing_plan_path(solidarity_plan, locale: I18n.default_locale)

    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(solidarity_plan, :pricing_tier)}", text: 'Solidarity — Small')
    expect(page).to have_css(
      "##{ActionView::RecordIdentifier.dom_id(solidarity_plan, :solidarity_description)}",
      text: 'For co-ops with fewer than 20 members.'
    )
  end

  it 'provision view exposes stable review anchors' do
    create(:better_together_billing_subscription, billing_plan: plan, billable_owner: community, beneficiary: community)
    capybara_login_as_platform_manager

    visit better_together.provision_platform_community_billing_path(community, locale: I18n.default_locale)

    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(community, :provision_platform_page)}")
    expect(page).to have_css('#community-platform-provision-form')
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(community, :provision_platform_next_steps)}")
  end

  it 'community edit exposes a stable billing entry point anchor' do
    capybara_login_as_platform_manager

    visit better_together.edit_community_path(community, locale: I18n.default_locale)

    expect(page).to have_css('#community-manage-billing-btn')
  end

  it 'community show exposes a stable billing entry point anchor' do
    capybara_login_as_platform_manager

    visit better_together.community_path(community, locale: I18n.default_locale)

    expect(page).to have_css('#community-show-manage-billing-btn')
  end

  it 'person edit exposes a stable billing entry point anchor' do
    capybara_login_as_platform_manager

    visit better_together.edit_person_path(id: platform_manager.person.slug, locale: I18n.default_locale)

    expect(page).to have_css('#person-manage-billing-btn')
  end

  it 'new billing plan form exposes stable review anchors' do
    capybara_login_as_platform_manager

    visit better_together.new_billing_plan_path(locale: I18n.default_locale)

    expect(page).to have_css('#billing-plan-form')
  end
end
# rubocop:enable Layout/LineLength
