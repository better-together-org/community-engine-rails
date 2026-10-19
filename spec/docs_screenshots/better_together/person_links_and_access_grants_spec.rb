# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for person links and access grants',
               :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::DocsScreenshotHelpers

  let(:locale) { I18n.default_locale }
  let(:password) { 'SecureTest123!@#' }
  let(:host_platform) { configure_host_platform }
  let(:peer_platform) do
    BetterTogether::Platform.find_by(identifier: 'docs-person-links-peer') ||
      create(:better_together_platform, name: 'Harbour Commons', identifier: 'docs-person-links-peer',
                                        external: true, privacy: 'public')
  end
  let(:connection) do
    create(:better_together_platform_connection, :active, source_platform: host_platform, target_platform: peer_platform)
  end
  let(:person_link) { create(:better_together_person_link, platform_connection: connection) }
  let(:access_grant) { create(:better_together_person_access_grant, person_link:, allow_private_posts: true) }
  let(:grantor_user) do
    create(:better_together_user, :confirmed, person: person_link.source_person, email: "grantor-#{SecureRandom.hex(3)}@example.test", password:)
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    access_grant
    grantor_user
  end

  after do
    Current.platform = nil
  end

  def sign_in_as_grantor
    capybara_sign_in_user(grantor_user.email, password)
  end

  it 'captures the person links list' do
    docs_screenshot('person_links_index', role: 'user', feature_set: 'person_links') do
      sign_in_as_grantor
      visit better_together.person_links_path(locale:)

      expect(page).to have_text('Person Links')
      expect(page).to have_text('Active')
    end
  end

  it 'captures a person link with its access grants' do
    docs_screenshot('person_links_show', role: 'user', feature_set: 'person_links') do
      sign_in_as_grantor
      visit better_together.person_link_path(person_link, locale:)

      expect(page).to have_text('Person Link')
      expect(page).to have_button('Revoke Link')
      expect(page).to have_text('Access Grants')
    end
  end

  it 'captures the access grants list' do
    docs_screenshot('person_access_grants_index', role: 'user', feature_set: 'person_access_grants') do
      sign_in_as_grantor
      visit better_together.person_access_grants_path(locale:)

      expect(page).to have_text('Access Grants')
      expect(page).to have_text('You are sharing')
    end
  end

  it 'captures an access grant with its scopes' do
    docs_screenshot('person_access_grants_show', role: 'user', feature_set: 'person_access_grants') do
      sign_in_as_grantor
      visit better_together.person_access_grant_path(access_grant, locale:)

      expect(page).to have_text('Access Grant')
      expect(page).to have_text('Scopes')
      expect(page).to have_text('Private posts')
    end
  end
end
