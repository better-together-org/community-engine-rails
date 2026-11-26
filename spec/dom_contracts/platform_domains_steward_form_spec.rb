# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the platform domain form. A steward only requests a domain, so the form shows an
# activation note in place of the Active checkbox; the governing operator keeps the checkbox. Docs
# screenshot specs target these identifiers.
RSpec.describe 'Platform domain form DOM contract', :skip_host_setup, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let(:setup) { managed_platform_setup }
  let(:new_domain_path) { better_together.new_platform_platform_domain_path(setup.managed_platform, locale:) }

  it 'gives the managed steward the activation note and no Active checkbox' do
    host_on(setup.managed_platform)
    sign_in_steward(setup.managed_steward)

    get new_domain_path
    expect(response).to have_http_status(:ok)
    doc = parsed_response

    expect(doc.at_css('#platform-domain-activation-note')).to be_present
    expect(doc.at_css('#platform_domain_active')).to be_blank
    expect(doc.at_css('#platform_domain_hostname')).to be_present
    expect(doc.at_css('#platform-domain-submit-btn')).to be_present
  end

  it 'gives the operator steward the Active checkbox and no note' do
    host_on(setup.operator_platform)
    sign_in_steward(setup.operator_steward)

    get new_domain_path
    expect(response).to have_http_status(:ok)
    doc = parsed_response

    expect(doc.at_css('#platform_domain_active')).to be_present
    expect(doc.at_css('#platform-domain-activation-note')).to be_blank
  end
end
