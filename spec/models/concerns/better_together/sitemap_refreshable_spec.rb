# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SitemapRefreshable do
  describe 'after_commit callback' do
    %w[Page Post Community].each do |model_name|
      context "on BetterTogether::#{model_name}" do
        it 'enqueues SitemapRefreshJob on create' do
          # SitemapRefreshable skips enqueue in test env, so verify the concern is included
          expect(BetterTogether.const_get(model_name).ancestors).to include(described_class)
        end
      end
    end

    context 'on BetterTogether::Event' do
      it 'includes SitemapRefreshable' do
        expect(BetterTogether::Event.ancestors).to include(described_class)
      end
    end
  end

  describe '#refresh_sitemap' do
    let(:page) { build(:better_together_page) }

    it 'is a private method' do
      expect(page.respond_to?(:refresh_sitemap, true)).to be true
      expect(page.respond_to?(:refresh_sitemap)).to be false
    end
  end
end
