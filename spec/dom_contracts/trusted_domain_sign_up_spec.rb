# frozen_string_literal: true

require 'rails_helper'

# The sign-up page advertises trusted domains and, on an invitation-only platform, exposes the registration form
# for them via ?trusted_domain=1 without opening sign-up to anyone else.
RSpec.describe 'Trusted domain sign-up DOM contract', :skip_host_setup, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let(:page_html) { Nokogiri::HTML(response.body) }
  let!(:platform) do
    configure_host_platform.tap { |host| host.update!(privacy: 'public', requires_invitation: true) }
  end

  it 'shows only the invitation form when no domain is trusted', :aggregate_failures do
    get new_user_registration_path(locale:, trusted_domain: 1)

    expect(page_html.at_css('#trusted-domain-confirmation-notice')).to be_nil
    expect(page_html.at_css('#trusted-domain-sign-up-prompt')).to be_nil
  end

  it 'exposes the registration form and confirmation notice for a trusted domain', :aggregate_failures do
    create(:platform_trusted_domain, platform:, domain: 'club.example.org')
    get new_user_registration_path(locale:, trusted_domain: 1)

    expect(page_html.at_css('#trusted-domain-confirmation-notice').text).to include('@club.example.org')
    expect(page_html.at_css('input[name="user[email]"]')).to be_present
  end

  it 'keeps the invitation-only gate without the trusted_domain flag', :aggregate_failures do
    create(:platform_trusted_domain, platform:, domain: 'club.example.org')
    get new_user_registration_path(locale:)

    expect(page_html.at_css('#trusted-domain-confirmation-notice')).to be_nil
    expect(page_html.at_css('input[name="user[email]"]')).to be_nil
  end
end
