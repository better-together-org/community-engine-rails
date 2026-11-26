# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the platform dashboard overview, as seen by a managed platform's steward. Docs
# screenshot specs target these identifiers; the counts must describe only the platform being viewed.
RSpec.describe 'Host dashboard overview DOM contract', :skip_host_setup, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let(:setup) { managed_platform_setup }

  before do
    create_list(:better_together_page, 2, platform: setup.managed_platform)
    create(:better_together_page, platform: setup.operator_platform)
    host_on(setup.managed_platform)
    sign_in_steward(setup.managed_steward)
  end

  it 'renders the overview sections for the managed steward' do
    get better_together.host_dashboard_path(locale:)
    expect(response).to have_http_status(:ok)
    doc = parsed_response

    %w[engagement-section content-section infrastructure-section].each do |id|
      expect(doc.at_css("##{id}")).to be_present, "expected ##{id}"
    end
  end

  it 'counts only the managed platform pages' do
    get better_together.host_dashboard_path(locale:)

    expect(assigns(:page_count)).to eq(2)
    expect(parsed_response.at_css('#host-dashboard-page-card')).to be_present
  end
end
