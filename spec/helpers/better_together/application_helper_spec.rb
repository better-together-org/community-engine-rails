# frozen_string_literal: true

require 'rails_helper'
require 'nokogiri'

module BetterTogether
  RSpec.describe ApplicationHelper, type: :helper do
    describe '#set_meta_description' do
      it 'stores translated description in content_for and renders meta tag' do
        allow(helper).to receive(:host_platform).and_return(double(name: 'MyPlatform'))
        allow(helper).to receive(:request).and_return(double(original_url: 'http://example.com'))
        allow(helper).to receive(:host_community_logo_url).and_return(nil)

        helper.set_meta_description('communities.index', platform_name: 'MyPlatform')

        expected = I18n.t('meta.descriptions.communities.index', platform_name: 'MyPlatform')
        expect(view.content_for(:meta_description)).to eq(expected)

        html = Nokogiri::HTML.fragment(helper.seo_meta_tags)
        meta = html.at('meta[name="description"]')
        expect(meta['content']).to eq(expected)
      end
    end
  end
end
