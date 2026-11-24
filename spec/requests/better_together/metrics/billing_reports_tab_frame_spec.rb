# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Billing reports inside the billing tab frame', :as_platform_manager do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:path) { better_together.metrics_billing_reports_path(locale:) }

  it 'wraps the page in the billing tab frame that asked for it, without the site layout', :aggregate_failures do
    get path, headers: { 'Turbo-Frame' => 'billing-tab-billing-reports' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<turbo-frame id="billing-tab-billing-reports">', 'id="billing_reports"')
    expect(response.body).not_to include('<html')
  end

  it 'keeps answering the reports frame itself with just that frame' do
    get path, headers: { 'Turbo-Frame' => 'billing_reports' }

    expect(response.body).not_to include('billing-tab-billing-reports')
  end
end
