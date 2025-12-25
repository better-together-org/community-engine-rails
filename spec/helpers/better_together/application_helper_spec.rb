# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe ApplicationHelper, type: :helper do
    before do
      allow(helper).to receive(:host_platform).and_return(double(name: 'Test Platform', cache_key_with_version: 'test-platform'))
      allow(helper).to receive(:host_community_logo_url).and_return(nil)
      allow(controller.request).to receive(:original_url).and_return('http://test.host/en/current')
      allow(I18n).to receive(:available_locales).and_return(%i[en fr])
      allow(helper).to receive(:url_for) do |opts|
        "http://test.host/#{opts[:locale]}/current"
      end
    end

    describe '#seo_meta_tags' do
      it 'includes default canonical and hreflang links' do
        html = helper.seo_meta_tags
        expect(html).to include('<link rel="canonical" href="http://test.host/en/current"')
        expect(html).to include('<link rel="alternate" hreflang="fr" href="http://test.host/fr/current"')
      end

      it 'merges content_for overrides' do
        helper.content_for(:canonical_url, 'http://example.com/custom')
        helper.content_for(:hreflang_links, tag.link(rel: 'alternate', hreflang: 'es', href: 'http://test.host/es/current'))

        html = helper.seo_meta_tags
        expect(html).to include('<link rel="canonical" href="http://example.com/custom"')
        expect(html).to include('<link rel="alternate" hreflang="fr" href="http://test.host/fr/current"')
        expect(html).to include('<link rel="alternate" hreflang="es" href="http://test.host/es/current"')
      end
    end

    describe '#open_graph_meta_tags' do
      it 'defaults og:url to canonical_url' do
        allow(helper).to receive(:canonical_url).and_return('http://test.host/en/current')
        html = helper.open_graph_meta_tags
        expect(html).to include('<meta property="og:url" content="http://test.host/en/current"')
      end

      it 'allows og_url override' do
        helper.content_for(:og_url, 'http://example.com/og')
        allow(helper).to receive(:canonical_url).and_return('http://test.host/en/current')
        html = helper.open_graph_meta_tags
        expect(html).to include('<meta property="og:url" content="http://example.com/og"')
      end
    end

    describe '#stimulus_debug_enabled?' do
      it 'returns true when debug param is "true"' do # rubocop:todo RSpec/RepeatedExample
        allow(helper).to receive_messages(params: { debug: 'true' }, session: {})

        expect(helper.stimulus_debug_enabled?).to be true
      end

      it 'returns false when debug param is not present' do
        allow(helper).to receive_messages(params: {}, session: {})

        expect(helper.stimulus_debug_enabled?).to be false
      end

      it 'returns true when session is active and not expired' do
        allow(helper).to receive_messages(params: {}, session: {
                                            stimulus_debug: true,
                                            stimulus_debug_expires_at: 10.minutes.from_now
                                          })

        expect(helper.stimulus_debug_enabled?).to be true
      end

      it 'returns false when session is expired' do
        allow(helper).to receive_messages(params: {}, session: {
                                            stimulus_debug: true,
                                            stimulus_debug_expires_at: 10.minutes.ago
                                          })

        expect(helper.stimulus_debug_enabled?).to be false
      end

      it 'returns false when session exists but no expiration time' do
        allow(helper).to receive_messages(params: {}, session: {
                                            stimulus_debug: true
                                          })

        expect(helper.stimulus_debug_enabled?).to be false
      end

      it 'prioritizes params over session' do # rubocop:todo RSpec/RepeatedExample
        allow(helper).to receive_messages(params: { debug: 'true' }, session: {})

        expect(helper.stimulus_debug_enabled?).to be true
      end
    end

    describe '#robots_meta_tag' do
      it 'renders default robots meta tag' do
        allow(helper).to receive(:stimulus_debug_enabled?).and_return(false)

        tag = helper.robots_meta_tag
        expect(tag).to include('name="robots"')
        expect(tag).to include('content="index,follow"')
      end

      it 'allows override via content_for' do
        allow(helper).to receive(:stimulus_debug_enabled?).and_return(false)
        view.content_for(:meta_robots, 'noindex,nofollow')

        tag = helper.robots_meta_tag
        expect(tag).to include('content="noindex,nofollow"')
      end

      it 'sets noindex,nofollow when debug mode is enabled' do
        allow(helper).to receive(:stimulus_debug_enabled?).and_return(true)

        tag = helper.robots_meta_tag
        expect(tag).to include('content="noindex,nofollow"')
      end

      it 'prioritizes debug mode over content_for' do
        allow(helper).to receive(:stimulus_debug_enabled?).and_return(true)
        view.content_for(:meta_robots, 'index,follow')

        tag = helper.robots_meta_tag
        expect(tag).to include('content="noindex,nofollow"')
      end
    end
  end
end
