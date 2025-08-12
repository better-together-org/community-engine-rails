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
  end
end
