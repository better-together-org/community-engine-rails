# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe ApplicationHelper, type: :helper do

    describe '#hreflang_links' do
      it 'returns alternate link tags for all locales' do
        allow(I18n).to receive(:available_locales).and_return(%i[en fr])
        allow(helper).to receive(:url_for) do |options|
          "http://example.com/#{options[:locale]}"
        end

        html = helper.hreflang_links

        expect(html).to include('rel="alternate" hreflang="en" href="http://example.com/en"')
        expect(html).to include('rel="alternate" hreflang="fr" href="http://example.com/fr"')
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
