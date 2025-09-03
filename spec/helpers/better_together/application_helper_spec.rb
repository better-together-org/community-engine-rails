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

    describe '#robots_meta_tag' do
      it 'renders default robots meta tag' do # rubocop:todo RSpec/MultipleExpectations
        tag = helper.robots_meta_tag
        expect(tag).to include('name="robots"')
        expect(tag).to include('content="index,follow"')
      end

      it 'allows override via content_for' do
        view.content_for(:meta_robots, 'noindex,nofollow')
        tag = helper.robots_meta_tag
        expect(tag).to include('content="noindex,nofollow"')
      end
    end
  end
end
