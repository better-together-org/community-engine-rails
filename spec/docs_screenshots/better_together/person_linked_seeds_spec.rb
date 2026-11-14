# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for linked seeds',
               :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::DocsScreenshotHelpers

  let(:locale) { I18n.default_locale }
  let(:password) { 'SecureTest123!@#' }
  let(:host_platform) { configure_host_platform }
  let(:peer_platform) do
    BetterTogether::Platform.find_by(identifier: 'docs-linked-seeds-peer') ||
      create(:better_together_platform, name: 'Hilltop Commons', identifier: 'docs-linked-seeds-peer',
                                        external: true, privacy: 'public')
  end
  let(:connection) do
    create(:better_together_platform_connection, :active, source_platform: peer_platform, target_platform: host_platform)
  end
  let(:person_link) { create(:better_together_person_link, platform_connection: connection) }
  let(:access_grant) { create(:better_together_person_access_grant, person_link:, allow_private_posts: true) }
  let(:recipient_user) do
    create(:better_together_user, :confirmed, person: access_grant.grantee_person,
                                              email: "recipient-#{SecureRandom.hex(3)}@example.test", password:)
  end
  let(:linked_seed) do
    create(:better_together_person_linked_seed,
           person_access_grant: access_grant, recipient_person: access_grant.grantee_person,
           payload: JSON.generate('title' => 'Seed swap notes', 'body' => 'Shared privately with you from Hilltop Commons.'))
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    linked_seed
    recipient_user
  end

  after do
    Current.platform = nil
  end

  it 'captures the linked seeds list' do
    docs_screenshot('person_linked_seeds_index', role: 'user', feature_set: 'person_linked_seeds') do
      capybara_sign_in_user(recipient_user.email, password)
      visit better_together.person_linked_seeds_path(locale:)

      expect(page).to have_text('Seed swap notes')
    end
  end

  it 'captures a linked seed' do
    docs_screenshot('person_linked_seeds_show', role: 'user', feature_set: 'person_linked_seeds') do
      capybara_sign_in_user(recipient_user.email, password)
      visit better_together.person_linked_seed_path(linked_seed, locale:)

      expect(page).to have_text('Seed swap notes')
    end
  end
end
