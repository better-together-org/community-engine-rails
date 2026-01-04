# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/SpecFilePathFormat, RSpec/DescribeMethod
RSpec.describe BetterTogether::Metrics::PageView, 'Platform URL tracking' do
  let(:platform) { create(:better_together_platform, :host) }
  let(:locale) { I18n.default_locale }

  describe 'when pageable is a Platform' do
    it 'stores the routing URL for the platform' do
      page_view = described_class.create!(
        pageable: platform,
        viewed_at: Time.current,
        locale: locale
      )

      # Platform.url should return the routing path like "/en/platforms/platform-slug"
      expect(page_view.page_url).to be_present
      expect(page_view.page_url).to include('/platforms/')
      expect(page_view.page_url).to include(platform.slug)
    end

    it 'calls Platform#url method for routing URL' do
      # Verify that Platform has the url method and it returns a routing path
      expect(platform).to respond_to(:url)
      platform_url = platform.url

      expect(platform_url).to be_present
      expect(platform_url).to include('/platforms/')
      expect(platform_url).to include(platform.slug)
    end

    it 'differentiates between host_url (external) and url (routing)' do
      # host_url is the external URL like "https://example.com"
      expect(platform.host_url).to match(%r{^https?://})

      # url is the routing URL (full URL with path) like "http://localhost:3000/en/platforms/slug"
      expect(platform.url).to match(%r{^https?://})
      expect(platform.url).to include('/platforms/')
      expect(platform.url).to include(platform.slug)
    end

    it 'returns nil for url method on new (unpersisted) records' do
      new_platform = build(:better_together_platform)
      expect(new_platform.persisted?).to be false
      expect(new_platform.url).to be_nil
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat, RSpec/DescribeMethod
