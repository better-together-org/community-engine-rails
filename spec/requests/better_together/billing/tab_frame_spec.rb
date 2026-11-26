# frozen_string_literal: true

require 'rails_helper'

# The host billing page loads each billing screen into a lazy Turbo Frame tab. A request from one of
# those frames gets the page content wrapped in the frame, not the full site layout.
RSpec.describe 'Billing screens loaded into host billing tabs', :as_platform_manager do
  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }

  before { BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[checkout catalog_sync lookups]) }) }

  it 'wraps the screen in the frame that asked for it, without the site layout', :aggregate_failures do
    get better_together.billing_plans_path(locale:), headers: { 'Turbo-Frame' => 'billing-tab-billing-plans' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="billing-tab-billing-plans"')
    expect(response.body).not_to include('<html')
  end

  it 'keeps the full layout for a normal request' do
    get better_together.billing_plans_path(locale:)

    expect(response.body).to include('<html')
  end

  it 'keeps the full layout for a frame that is not a billing tab' do
    get better_together.billing_plans_path(locale:), headers: { 'Turbo-Frame' => 'host-dashboard-tab-content' }

    expect(response.body).not_to include('<turbo-frame id="billing-tab-')
  end

  it 'tells browsers the answer depends on whether a frame asked, so a prefetched page is not reused in a tab' do
    get better_together.billing_agreement_requirements_path(locale: I18n.default_locale)

    expect(response.headers['Vary']).to include('Turbo-Frame')
  end

  it 'switches off link prefetching inside a tab frame (the prefetch cache ignores the frame header)', :aggregate_failures do
    get better_together.billing_agreement_requirements_path(locale: I18n.default_locale),
        headers: { 'Turbo-Frame' => 'billing-tab-billing-agreement-requirements' }

    expect(response.body).to include('data-turbo-prefetch="false"')
  end
end
