# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Redirect do
  let(:platform) { create(:better_together_platform) }

  describe '.normalize_path' do
    it 'decodes, adds the leading slash and drops query, fragment and trailing slash' do
      expect(described_class.normalize_path('pdf/Omphalina%20XII.pdf?x=1#top')).to eq('/pdf/Omphalina XII.pdf')
      expect(described_class.normalize_path('/about/')).to eq('/about')
      expect(described_class.normalize_path('/')).to eq('/')
    end
  end

  describe 'validations' do
    it 'normalizes the from path on save' do
      redirect = create(:better_together_redirect, platform:, from_path: 'Old/Page.html/')

      expect(redirect.from_path).to eq('/Old/Page.html')
    end

    it 'is unique per platform, ignoring case, but may repeat across platforms' do
      create(:better_together_redirect, platform:, from_path: '/about')
      other = create(:better_together_platform)

      expect(build(:better_together_redirect, platform:, from_path: '/ABOUT')).not_to be_valid
      expect(build(:better_together_redirect, platform: other, from_path: '/about')).to be_valid
    end

    it 'requires a destination unless the status is 410' do
      expect(build(:better_together_redirect, platform:, to_path: nil)).not_to be_valid
      expect(build(:better_together_redirect, :gone, platform:)).to be_valid
    end

    it 'accepts site paths and http or https URLs only' do
      expect(build(:better_together_redirect, platform:, to_path: 'https://example.test/x')).to be_valid
      expect(build(:better_together_redirect, platform:, to_path: 'javascript:alert(1)')).not_to be_valid
      expect(build(:better_together_redirect, platform:, to_path: '//evil.test/x')).not_to be_valid
    end

    it 'rejects a redirect to itself and a loop through other redirects' do
      create(:better_together_redirect, platform:, from_path: '/b', to_path: '/a')

      expect(build(:better_together_redirect, platform:, from_path: '/c', to_path: '/c')).not_to be_valid
      loop_row = build(:better_together_redirect, platform:, from_path: '/a', to_path: '/b')
      expect(loop_row).not_to be_valid
      expect(loop_row.errors[:to_path]).to include('leads back to itself through other redirects')
    end
  end

  describe BetterTogether::Redirects::Resolver do
    it 'finds an active redirect case-insensitively and only on its own platform' do
      redirect = create(:better_together_redirect, platform:, from_path: '/Old.html', to_path: '/en/new')
      other = create(:better_together_platform)

      found = described_class.call(platform_id: platform.id, path: '/old.HTML')
      expect(found.id).to eq(redirect.id)
      expect(found.to_path).to eq('/en/new')
      expect(described_class.call(platform_id: other.id, path: '/old.html')).to be_nil
    end

    it 'ignores inactive redirects and picks up changes after the cache is busted' do
      redirect = create(:better_together_redirect, platform:, from_path: '/x')
      expect(described_class.call(platform_id: platform.id, path: '/x')).to be_present

      redirect.update!(active: false)

      expect(described_class.call(platform_id: platform.id, path: '/x')).to be_nil
    end
  end
end
