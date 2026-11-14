# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Third-party tracking exclusions' do
  let(:locale) { I18n.default_locale }
  let(:marker) { 'vendor-script-marker' }

  def make_page(privacy)
    slug = "tracking-#{privacy}-#{SecureRandom.hex(4)}"
    page = create(:better_together_page, slug:, identifier: slug, protected: false,
                                         published_at: 1.day.ago, privacy:)
    page.page_blocks.create!(block: create(:content_markdown, markdown_source: '## Hello'), position: 0)
    page
  end

  def tracking_meta
    Nokogiri::HTML(response.body).at_css('meta[name="bt-third-party-tracking"]')&.[]('content')
  end

  before do
    BetterTogether.register_head_tag_provider(:tracking_test) do |view_context|
      view_context.tag.meta(name: 'vendor', content: marker) if view_context.third_party_tracking_allowed?
    end
  end

  after { BetterTogether.head_tag_providers.delete(:tracking_test) }

  context 'when anonymous', :no_auth do
    it 'allows a public page and lets vendors render' do
      page = make_page('public')

      get better_together.render_page_path(path: page.slug, locale:)

      expect(response).to have_http_status(:ok)
      expect(tracking_meta).to eq('on')
      expect(response.body).to include(marker)
    end

    it 'excludes a public page whose URL carries a token' do
      page = make_page('public')

      get better_together.render_page_path(path: page.slug, locale:, token: 'abc')

      expect(tracking_meta).to eq('off')
      expect(response.body).not_to include(marker)
    end

    it 'excludes the sign-in page' do
      get better_together.new_user_session_path(locale:)

      expect(tracking_meta).to eq('off')
      expect(response.body).not_to include(marker)
    end

    it 'excludes an error response' do
      get better_together.render_page_path(path: "missing-#{SecureRandom.hex(4)}", locale:)

      expect(response).not_to have_http_status(:ok)
      expect(response.body).not_to include(marker)
    end
  end

  context 'when signed in', :as_platform_manager do
    it 'allows a public record' do
      page = make_page('public')

      get better_together.render_page_path(path: page.slug, locale:)

      expect(tracking_meta).to eq('on')
    end

    it 'excludes a non-public record' do
      page = make_page('private')

      get better_together.render_page_path(path: page.slug, locale:)

      expect(response).to have_http_status(:ok)
      expect(tracking_meta).to eq('off')
      expect(response.body).not_to include(marker)
    end

    it 'excludes conversations' do
      get better_together.conversations_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(tracking_meta).to eq('off')
      expect(response.body).not_to include(marker)
    end

    it 'excludes the host dashboard' do
      get better_together.host_dashboard_path(locale:)

      expect(tracking_meta).to eq('off')
    end

    it 'honours exclusions registered by extensions' do
      page = make_page('public')
      BetterTogether.register_third_party_tracking_exclusion(:test_rule) { |_controller| true }

      begin
        get better_together.render_page_path(path: page.slug, locale:)

        expect(tracking_meta).to eq('off')
      ensure
        BetterTogether.third_party_tracking_exclusions.delete(:test_rule)
      end
    end
  end
end
