# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Sitemaps::IndexBuilder do
  let(:platform) do
    BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host, :public)
  end

  before do
    platform.update!(host_url: 'https://tenant.example.test')
  end

  def decompressed(io)
    Zlib::GzipReader.new(io).read
  end

  it 'references the controller-served locale URLs on the platform resolved host' do
    xml = described_class.new(platform: platform, locales: %i[en es]).to_xml

    expect(xml).to include('<loc>https://tenant.example.test/en/sitemap.xml.gz</loc>')
    expect(xml).to include('<loc>https://tenant.example.test/es/sitemap.xml.gz</loc>')
    expect(xml).to include('<sitemapindex')
  end

  it 'only lists the locales it was given, sorted deterministically' do
    xml = described_class.new(platform: platform, locales: %w[es en]).to_xml

    expect(xml.index('/en/sitemap.xml.gz')).to be < xml.index('/es/sitemap.xml.gz')
    expect(xml).not_to include('/fr/sitemap.xml.gz')
  end

  it 'emits <lastmod> from the matching per-locale sitemap blob when present' do
    record = BetterTogether::Sitemap.current(platform, :en)
    record.file.attach(io: StringIO.new('x'), filename: 'sitemap_en.xml.gz', content_type: 'application/gzip')

    xml = described_class.new(platform: platform, locales: %i[en]).to_xml

    expect(xml).to match(%r{<lastmod>#{Regexp.escape(record.file.blob.created_at.iso8601)}</lastmod>})
  end

  it 'produces a gzipped, rewound IO' do
    io = described_class.new(platform: platform, locales: %i[en]).to_gzipped_io

    expect(io.pos).to eq(0)
    expect(decompressed(io)).to include('<sitemapindex')
  end
end
