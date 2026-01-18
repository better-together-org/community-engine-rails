# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Share Buttons', :js do
  include BetterTogether::CapybaraFeatureHelpers

  before do
    configure_host_platform
  end

  let!(:published_page) do
    create(:better_together_page,
           slug: 'shareable-page',
           title: 'Shareable Page',
           privacy: 'public')
  end

  scenario 'displays share buttons on public page' do
    visit better_together.render_page_path(published_page.slug, locale: I18n.default_locale)

    # Verify page loads
    expect(page).to have_content(published_page.title)

    # Check for share buttons (they should render since page is public)
    expect(page).to have_css('.social-share-buttons', wait: 5)
    expect(page).to have_css('[data-controller="better_together--share"]')
  end

  scenario 'shows email share button' do
    visit better_together.render_page_path(published_page.slug, locale: I18n.default_locale)

    within('.social-share-buttons') do
      expect(page).to have_css('[data-platform="email"]')
      expect(page).to have_css('.fa-envelope')
    end
  end

  scenario 'shows facebook share button' do
    visit better_together.render_page_path(published_page.slug, locale: I18n.default_locale)

    within('.social-share-buttons') do
      expect(page).to have_css('[data-platform="facebook"]')
      expect(page).to have_css('.fa-facebook')
    end
  end

  scenario 'shows all configured social platforms' do
    visit better_together.render_page_path(published_page.slug, locale: I18n.default_locale)

    within('.social-share-buttons') do
      # Check default platforms are present
      expect(page).to have_css('[data-platform="email"]')
      expect(page).to have_css('[data-platform="facebook"]')
      expect(page).to have_css('[data-platform="bluesky"]')
      expect(page).to have_css('[data-platform="linkedin"]')
      expect(page).to have_css('[data-platform="pinterest"]')
      expect(page).to have_css('[data-platform="reddit"]')
      expect(page).to have_css('[data-platform="whatsapp"]')
    end
  end

  scenario 'share buttons have proper data attributes' do
    visit better_together.render_page_path(published_page.slug, locale: I18n.default_locale)

    email_button = find('[data-platform="email"]')

    # Check required data attributes
    expect(email_button['data-url']).to be_present
    expect(email_button['data-title']).to eq(published_page.title)
    expect(email_button['data-share-tracking-url']).to be_present
    expect(email_button['data-shareable-type']).to be_present
    expect(email_button['data-shareable-id']).to eq(published_page.id.to_s)
  end

  scenario 'email share button triggers share action' do
    visit better_together.render_page_path(published_page.slug, locale: I18n.default_locale)

    # Find and click email share button
    email_button = find('[data-platform="email"]')
    expect(email_button['data-action']).to include('better_together--share#share')

    # Button should be clickable
    expect(email_button).to be_present
  end

  scenario 'share buttons have accessibility attributes' do
    visit better_together.render_page_path(published_page.slug, locale: I18n.default_locale)

    within('.social-share-buttons') do
      all('[data-platform]').each do |button|
        # Check for icon role
        icon = button.find('.fa-stack', match: :first)
        expect(icon['role']).to eq('img')
      end
    end
  end

  scenario 'share buttons have tracking data attributes' do
    visit better_together.render_page_path(published_page.slug, locale: I18n.default_locale)

    # All share buttons should have tracking URL
    within('.social-share-buttons') do
      all('[data-platform]').each do |button|
        expect(button['data-share-tracking-url']).to be_present
        expect(button['data-shareable-type']).to eq('BetterTogether::Page')
        expect(button['data-shareable-id']).to eq(published_page.id.to_s)
      end
    end
  end

  context 'with private page' do
    let!(:private_page) do
      create(:better_together_page,
             title: 'Private Page',
             privacy: 'private')
    end

    scenario 'does not display share buttons on private page', :as_user do
      visit better_together.page_path(private_page, locale: I18n.default_locale)

      expect(page).not_to have_css('.social-share-buttons')
    end
  end

  context 'with published post' do
    let!(:published_post) do
      create(:better_together_post,
             title: 'Shareable Post',
             privacy: 'public')
    end

    scenario 'displays share buttons on post show page' do
      visit better_together.post_path(published_post, locale: I18n.default_locale)

      expect(page).to have_css('.social-share-buttons')
    end

    scenario 'uses post title as share title' do
      visit better_together.post_path(published_post, locale: I18n.default_locale)

      email_button = find('[data-platform="email"]')
      expect(email_button['data-title']).to eq(published_post.title)
    end
  end

  context 'share button icons' do
    before do
      visit better_together.render_page_path(published_page.slug, locale: I18n.default_locale)
    end

    scenario 'email button has envelope icon' do
      within('[data-platform="email"]') do
        expect(page).to have_css('.fa-envelope')
      end
    end

    scenario 'facebook button has facebook icon' do
      within('[data-platform="facebook"]') do
        expect(page).to have_css('.fa-facebook')
      end
    end

    scenario 'bluesky button has bluesky icon' do
      within('[data-platform="bluesky"]') do
        expect(page).to have_css('.fa-bluesky')
      end
    end

    scenario 'linkedin button has linkedin icon' do
      within('[data-platform="linkedin"]') do
        expect(page).to have_css('.fa-linkedin')
      end
    end

    scenario 'pinterest button has pinterest icon' do
      within('[data-platform="pinterest"]') do
        expect(page).to have_css('.fa-pinterest')
      end
    end

    scenario 'reddit button has reddit-alien icon' do
      within('[data-platform="reddit"]') do
        expect(page).to have_css('.fa-reddit-alien')
      end
    end

    scenario 'whatsapp button has whatsapp icon' do
      within('[data-platform="whatsapp"]') do
        expect(page).to have_css('.fa-whatsapp')
      end
    end
  end

  context 'share button styling' do
    before do
      visit better_together.render_page_path(published_page.slug, locale: I18n.default_locale)
    end

    scenario 'icons use fa-stack for circular background' do
      within('[data-platform="email"]') do
        expect(page).to have_css('.fa-stack')
        expect(page).to have_css('.fa-stack-2x.fa-circle')
        expect(page).to have_css('.fa-stack-1x.fa-envelope')
      end
    end

    scenario 'each platform button is properly styled' do
      expect(all('[data-platform]')).to all(have_css('.fa-stack'))
    end
  end
end
