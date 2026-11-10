# frozen_string_literal: true

require 'rails_helper'

# The readiness checklist points a steward at the seed catalog when no purchase agreement exists yet.
# Screenshot: spec/docs_screenshots/better_together/billing_readiness_plant_link_spec.rb.
RSpec.describe 'Billing readiness plant link DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:agreement_ids) { %w[subscription_agreement one_time_purchase_agreement offline_payment_terms] }

  def remove_agreements
    host_platform.billing_agreement_requirements.destroy_all
    BetterTogether::Agreement.where(platform: host_platform, identifier: agreement_ids).destroy_all
  end

  it 'links each purchase with no agreement to the billing agreements section of the seed catalog', :aggregate_failures do
    remove_agreements

    get "/#{locale}/billing/agreement_requirements"

    %w[subscription one_time].each do |purpose|
      expect(response.body).to include(%(id="billing-readiness-plant-agreements-#{purpose}"))
    end
    expect(response.body).to include('/host/seeds/catalog', '#seed-catalog-billing_agreements')
  end

  it 'offers no link once the agreements exist, even as drafts' do
    purchase_agreements_for(host_platform)

    get "/#{locale}/billing/agreement_requirements"

    expect(response.body).not_to include('billing-readiness-plant-agreements')
  end
end
