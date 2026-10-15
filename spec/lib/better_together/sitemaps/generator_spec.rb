# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Sitemaps::Generator do
  let!(:host_platform) do
    (BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host, :public)).tap do |p|
      p.update!(host_url: 'https://host.example.test', privacy: 'public')
    end
  end

  let!(:tenant_platform) do
    create(:better_together_platform, :public, host: false, external: false,
                                               host_url: 'https://tenant.example.test')
  end

  def locale_xml(platform, locale = :en)
    record = BetterTogether::Sitemap.find_by(platform: platform, locale: locale.to_s)
    return nil unless record&.file&.attached?

    Zlib::GzipReader.new(StringIO.new(record.file.download)).read
  end

  describe '#initialize' do
    it 'rejects an external platform' do
      external = create(:better_together_platform, :external)

      expect { described_class.new(external) }.to raise_error(described_class::NotLocalHostedError)
    end
  end

  describe '#call' do
    before do
      create(:better_together_page, platform: host_platform, privacy: 'public')
      create(:better_together_page, platform: tenant_platform, privacy: 'public')
    end

    it 'creates a per-locale sitemap plus an index for the platform' do
      described_class.new(tenant_platform).call

      locales = BetterTogether::Sitemap.where(platform: tenant_platform).pluck(:locale)
      expect(locales).to include('index')
      expect(locales).to include(*I18n.available_locales.map(&:to_s))
      expect(BetterTogether::Sitemap.where(platform: tenant_platform).all? { |s| s.file.attached? }).to be(true)
    end

    it 'hosts the tenant sitemap URLs on the tenant domain, not the host domain' do
      described_class.new(tenant_platform).call

      xml = locale_xml(tenant_platform)
      expect(xml).to include('https://tenant.example.test/')
      expect(xml).not_to include('https://host.example.test/')
    end

    it 'does not index another platform content' do
      other_page = create(:better_together_page, platform: host_platform, privacy: 'public', slug: 'host-only-page')
      described_class.new(tenant_platform).call

      expect(locale_xml(tenant_platform)).not_to include(other_page.slug)
    end

    it 'is idempotent - a second run with no changes attaches no new blob' do
      described_class.new(tenant_platform).call
      expect { described_class.new(tenant_platform).call }.not_to change(ActiveStorage::Blob, :count)
    end

    it 'points the index at the controller-served locale routes' do
      described_class.new(tenant_platform).call

      index = BetterTogether::Sitemap.find_by(platform: tenant_platform, locale: 'index')
      xml = Zlib::GzipReader.new(StringIO.new(index.file.download)).read
      expect(xml).to include('<loc>https://tenant.example.test/en/sitemap.xml.gz</loc>')
    end
  end
end
