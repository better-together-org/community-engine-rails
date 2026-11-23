# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Host dashboard billing page', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  it 'shows the readiness checklist to a platform manager' do
    get better_together.host_dashboard_billing_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('host-dashboard-billing-readiness')
  end

  it 'is not found for a signed-in member' do
    sign_in create(:better_together_user, :confirmed)

    get better_together.host_dashboard_billing_path(locale:)

    expect(response).to have_http_status(:not_found)
  end
end
