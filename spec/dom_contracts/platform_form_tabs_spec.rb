# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the tabbed platform edit form. Docs screenshot and feature specs
# target these identifiers, and every pre-existing field keeps its name.
RSpec.describe 'Platform form tabs DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:tabs) { %w[details access appearance domains security features] }
  let(:edit_path) { better_together.edit_platform_path(locale: I18n.default_locale, id: host_platform.slug) }

  it 'renders one pill and one pane per tab, with Details active first' do # rubocop:disable RSpec/MultipleExpectations
    get edit_path
    doc = parsed_response

    expect(doc.at_css('#platform-form-tabs')['role']).to eq('tablist')
    tabs.each do |tab|
      button = doc.at_css("#platform-#{tab}-tab")
      expect(button['aria-controls']).to eq("platform-#{tab}")
      expect(doc.at_css("#platform-#{tab}")['aria-labelledby']).to eq("platform-#{tab}-tab")
    end
    expect(doc.at_css('#platform-details-tab')['aria-selected']).to eq('true')
    expect(doc.css('#platform-form-tabs .nav-link.active').size).to eq(1)
  end

  it 'keeps every field name and its stable id' do # rubocop:disable RSpec/MultipleExpectations
    get edit_path
    doc = parsed_response
    dom_id = ActionView::RecordIdentifier.dom_id(host_platform)

    %w[identifier host_url time_zone privacy requires_invitation allow_membership_requests].each do |field|
      expect(doc.at_css("##{dom_id}_#{field}")).to be_present, "missing ##{dom_id}_#{field}"
    end
    %w[csp_frame_ancestors_text csp_frame_src_text csp_img_src_text csp_script_src_text
       csp_connect_src_text].each do |field|
      expect(doc.at_css("select[name='platform[#{field}][]']")).to be_present, "missing #{field}"
    end
    expect(doc.at_css("[name='platform[css_block_attributes][type]'], textarea[name^='platform[css_block_attributes]']"))
      .to be_present
  end

  it 'places fields on the tab that matches their purpose' do # rubocop:disable RSpec/MultipleExpectations
    get edit_path
    doc = parsed_response
    dom_id = ActionView::RecordIdentifier.dom_id(host_platform)

    expect(doc.at_css("#platform-details ##{dom_id}_identifier")).to be_present
    expect(doc.at_css("#platform-access ##{dom_id}_requires_invitation")).to be_present
    expect(doc.at_css("#platform-security ##{ActionView::RecordIdentifier.dom_id(host_platform, 'csp_settings')}"))
      .to be_present
    expect(doc.at_css("#platform-features ##{ActionView::RecordIdentifier.dom_id(host_platform, :quota_defaults)}"))
      .to be_present
  end

  it 'opens the tab holding the first error and shows an error count on it' do # rubocop:disable RSpec/MultipleExpectations
    patch better_together.platform_path(locale: I18n.default_locale, id: host_platform.slug),
          params: { platform: { csp_frame_src_text: ['ftp://bad origin'] } }
    doc = parsed_response

    expect(response).to have_http_status(:unprocessable_content)
    expect(doc.at_css('#platform-security-tab')['aria-selected']).to eq('true')
    expect(doc.at_css('#platform-security-tab-errors').text).to match(/\d/)
    expect(doc.at_css('#platform-details-tab-errors')).to be_nil
  end

  it 'exposes the extra tab hook pair for host apps' do
    get edit_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('platform-form-tabs-content')
  end
end
