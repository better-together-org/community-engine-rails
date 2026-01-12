# frozen_string_literal: true

require 'rails_helper'
require 'zlib'

RSpec.describe BetterTogether::SitemapRefreshJob, type: :job do
  before do
    # Stub search engine ping to prevent actual HTTP requests
    stub_request(:get, /google.com\/webmasters\/tools\/ping/).to_return(status: 200, body: '', headers: {})
  end

  it 'generates and attaches a sitemap' do
    host_platform = create(:platform, :host)
    BetterTogether::Sitemap.destroy_all

    described_class.new.perform

    expect(BetterTogether::Sitemap.current(host_platform).file).to be_attached
  end

  it 'includes only public pages in the sitemap' do
    host_platform = create(:platform, :host)
    public_page = create(:page, privacy: 'public', slug: 'public-page')
    private_page = create(:page, privacy: 'private', slug: 'private-page')
    BetterTogether::Sitemap.destroy_all

    described_class.perform_now

    data = BetterTogether::Sitemap.current(host_platform).file.download
    xml = Zlib::GzipReader.new(StringIO.new(data)).read

    expect(xml).to include(public_page.slug)
    expect(xml).not_to include(private_page.slug)
  end
end
