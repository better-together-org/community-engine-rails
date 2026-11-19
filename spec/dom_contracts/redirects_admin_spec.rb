# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the redirects admin UI. Docs screenshot specs target these identifiers.
RSpec.describe 'Redirects admin DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let(:platform) { BetterTogether::Platform.find_by(host: true) }

  it 'renders the index controls, table and row identifiers' do # rubocop:disable RSpec/MultipleExpectations
    redirect = create(:better_together_redirect, platform:)

    get platform_redirects_path(platform, locale:)
    doc = parsed_response

    %w[new-redirect-btn import-redirects-btn redirects-search-form redirects-table].each do |id|
      expect(doc.at_css("##{id}")).to be_present, "missing ##{id}"
    end
    expect(doc.at_css("##{ActionView::RecordIdentifier.dom_id(redirect)} .redirect-status-badge")).to be_present
    expect(doc.at_css("##{ActionView::RecordIdentifier.dom_id(redirect, :actions)}")).to be_present
  end

  it 'renders the form field ids' do
    get new_platform_redirect_path(platform, locale:)

    %w[redirect_from_path redirect_to_path redirect_status redirect_preserve_query redirect_active
       redirect-submit-btn].each do |id|
      expect(parsed_response.at_css("##{id}")).to be_present, "missing ##{id}"
    end
  end

  it 'renders the import form and its report identifiers' do # rubocop:disable RSpec/MultipleExpectations
    post import_platform_redirects_path(platform, locale:), params: { rows: '/a,/en/a' }
    doc = parsed_response

    %w[redirects_import_rows redirects-import-preview-btn redirects-import-apply-btn redirects-import-report
       redirects-import-created].each do |id|
      expect(doc.at_css("##{id}")).to be_present, "missing ##{id}"
    end
  end
end
