# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the custom code admin pages. Docs screenshot specs target these identifiers.
RSpec.describe 'Platform snippets DOM contract', :no_auth, type: :request do # rubocop:disable RSpec/DescribeClass
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let(:platform) { configure_host_platform }
  let(:manager) do
    user = find_or_create_test_user('snippet-dom@example.test', 'SecureTest123!@#', :user)
    platform.person_platform_memberships.find_or_create_by!(
      member: user.person, role: BetterTogether::Role.find_by!(identifier: 'platform_code_manager'), status: 'active'
    )
    user
  end
  let!(:snippet) do
    BetterTogether::PlatformSnippet.create!(platform:, name: 'Tracker', location: 'head_end',
                                            kind: 'script_inline', content: 'x()')
  end

  before { sign_in manager }

  it 'exposes the index identifiers' do # rubocop:disable RSpec/MultipleExpectations
    get better_together.platform_platform_snippets_path(platform, locale:)
    doc = Nokogiri::HTML(response.body)

    expect(response).to have_http_status(:ok)
    %w[new-platform-snippet-btn platform-snippets-warning platform-snippets-kill-switch
       platform-snippets-switch-btn platform-snippets-table platform-snippets-audit].each do |id|
      expect(doc.at_css("##{id}")).to be_present, "missing ##{id}"
    end
    expect(doc.at_css("##{ActionView::RecordIdentifier.dom_id(snippet)}")).to be_present
    expect(doc.at_css("##{ActionView::RecordIdentifier.dom_id(snippet, :actions)}")).to be_present
  end

  it 'exposes the form fields with stable ids and labels' do # rubocop:disable RSpec/MultipleExpectations
    get better_together.new_platform_platform_snippet_path(platform, locale:)
    doc = Nokogiri::HTML(response.body)

    %w[name location kind content src consent_category applies_to notes enabled].each do |field|
      input = doc.at_css("#platform_snippet_#{field}")
      expect(input).to be_present, "missing #{field}"
      expect(doc.at_css("label[for='platform_snippet_#{field}']")).to be_present, "no label for #{field}"
    end
    expect(doc.at_css('#platform-snippet-submit-btn')).to be_present
  end

  it 'links to the page from the platform form for a steward who also manages code' do # rubocop:disable RSpec/MultipleExpectations
    platform.person_platform_memberships.find_or_create_by!(
      member: manager.person, role: BetterTogether::Role.find_by!(identifier: 'platform_steward'), status: 'active'
    )
    get better_together.edit_platform_path(platform, locale:)
    doc = Nokogiri::HTML(response.body)

    expect(doc.at_css('#platform-integrations-tab')).to be_present
    expect(doc.at_css("##{ActionView::RecordIdentifier.dom_id(platform)}_custom_code_link")['href'])
      .to include('platform_snippets')
  end
end
