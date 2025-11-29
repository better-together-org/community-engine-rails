# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe ApplicationHelper, type: :helper do
    describe '#canonical_link_tag' do
      before do
        allow(helper).to receive(:base_url_with_locale).and_return('https://example.com/en')
      end

      context 'when no canonical_url is provided' do
        it 'defaults to request.original_url' do
          allow(helper.request).to receive(:original_url).and_return('https://example.com/en/posts')
          result = helper.canonical_link_tag
          expect(result).to include('href="https://example.com/en/posts"')
        end
      end

      context 'when canonical_url is a relative path with locale' do
        it 'prefixes base_url_with_locale and removes duplicate locale' do
          helper.content_for(:canonical_url, '/en/custom')
          result = helper.canonical_link_tag
          expect(result).to include('href="https://example.com/en/custom"')
        end
      end

      context 'when canonical_url is a full URL' do
        it 'uses the provided URL' do
          helper.content_for(:canonical_url, 'https://external.test/path')
          result = helper.canonical_link_tag
          expect(result).to include('href="https://external.test/path"')
        end
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
