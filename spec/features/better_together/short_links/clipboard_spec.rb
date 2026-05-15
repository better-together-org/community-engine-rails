# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Short Link Clipboard Controller', :js do
  include BetterTogether::CapybaraFeatureHelpers

  before { configure_host_platform }

  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

  # Injects a synchronous navigator.clipboard stub so tests can assert what
  # the controller passed to writeText without any async clipboard API.
  def mock_clipboard
    page.execute_script(<<~JS)
      window.copiedText = null;
      Object.defineProperty(navigator, 'clipboard', {
        configurable: true,
        value: { writeText: function(t){ window.copiedText = t; return Promise.resolve(); } }
      });
    JS
  end

  # ------------------------------------------------------------------ show page
  describe 'Short Links show page' do
    let!(:short_link) do
      create(:better_together_short_link,
             platform: host_platform,
             target_url: 'https://example.com/destination',
             status: 'active',
             expires_at: nil)
    end

    before do
      capybara_login_as_platform_manager
      visit better_together.short_link_path(short_link, locale: I18n.default_locale)
    end

    scenario 'clipboard controller is wired to the wrapper element' do
      expect(page).to have_css('[data-controller="better_together--clipboard"]')
    end

    scenario 'wrapper carries the short link URL as the url-value' do
      wrapper = find('[data-controller="better_together--clipboard"]')
      expect(wrapper['data-better_together--clipboard-url-value']).to eq(short_link.url)
    end

    scenario 'copy button writes the short link URL to the clipboard' do
      mock_clipboard
      find('[data-better_together--clipboard-target="button"]').click
      expect(page.evaluate_script('window.copiedText')).to eq(short_link.url)
    end
  end

  # ----------------------------------------------------------------- index page
  describe 'Short Links index page' do
    let!(:short_link) do
      create(:better_together_short_link,
             platform: host_platform,
             target_url: 'https://example.com/destination',
             status: 'active',
             expires_at: nil)
    end

    before do
      capybara_login_as_platform_manager
      visit better_together.short_links_path(locale: I18n.default_locale)
    end

    scenario 'each row has a clipboard controller with the correct url-value' do
      wrapper = find('[data-controller="better_together--clipboard"]', match: :first)
      expect(wrapper['data-better_together--clipboard-url-value']).to eq(short_link.url)
    end

    scenario 'row copy button writes the short link URL to the clipboard' do
      mock_clipboard
      find('[data-better_together--clipboard-target="button"]', match: :first).click
      expect(page.evaluate_script('window.copiedText')).to eq(short_link.url)
    end
  end

  # --------------------------------------------------------- share button panel
  # The _share_link_button partial is rendered (instead of the POST/ensure button)
  # when the linkable already has an active, unexpired short link.  Only this
  # partial contains <i class="... icon ..."> so _flashIcon() is exercised here.
  describe 'Share button panel (share link partial)' do
    let!(:published_page) do
      create(:better_together_page,
             platform: host_platform,
             slug: 'clipboard-short-link-page',
             title: 'Clipboard Test Page',
             privacy: 'public',
             published_at: 1.day.ago)
    end

    let!(:short_link) do
      create(:better_together_short_link,
             platform: host_platform,
             linkable: published_page,
             target_url: 'https://example.com/destination',
             status: 'active',
             expires_at: nil)
    end

    before do
      visit better_together.render_page_path(published_page.slug, locale: I18n.default_locale)
      find('.social-share-buttons', wait: 5)
    end

    scenario 'clipboard controller connects within the share buttons panel' do
      within('.social-share-buttons') do
        expect(page).to have_css('[data-controller="better_together--clipboard"]')
      end
    end

    scenario 'copy button carries the short link URL as the url-value' do
      within('.social-share-buttons') do
        wrapper = find('[data-controller="better_together--clipboard"]')
        expect(wrapper['data-better_together--clipboard-url-value']).to eq(short_link.url)
      end
    end

    scenario 'copy button writes the short link URL to the clipboard' do
      mock_clipboard
      within('.social-share-buttons') do
        find('[data-better_together--clipboard-target="button"]').click
      end
      expect(page.evaluate_script('window.copiedText')).to eq(short_link.url)
    end

    scenario 'icon flips to fa-check immediately after copy' do
      mock_clipboard
      within('.social-share-buttons') do
        find('[data-better_together--clipboard-target="button"]').click
        expect(page).to have_css('i.icon.fa-check', wait: 2)
      end
    end

    scenario 'icon resets to fa-link after 2 seconds' do
      mock_clipboard
      within('.social-share-buttons') do
        find('[data-better_together--clipboard-target="button"]').click
        expect(page).to have_css('i.icon.fa-check', wait: 2)
        expect(page).to have_css('i.icon.fa-link', wait: 4)
      end
    end
  end
end
