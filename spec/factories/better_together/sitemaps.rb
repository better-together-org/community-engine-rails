# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_sitemap, class: 'BetterTogether::Sitemap', aliases: [:sitemap] do
    association :platform, factory: :better_together_platform
    locale { I18n.default_locale.to_s }

    after(:build) do |sitemap|
      # Attach a test sitemap file if not already attached
      unless sitemap.file.attached?
        sitemap.file.attach(
          io: StringIO.new(BetterTogether::SitemapFactory.gzipped_sitemap_content),
          filename: "sitemap_#{sitemap.locale}.xml.gz",
          content_type: 'application/gzip'
        )
      end
    end

    trait :with_index do
      locale { 'index' }

      after(:build) do |sitemap|
        sitemap.file.attach(
          io: StringIO.new(BetterTogether::SitemapFactory.gzipped_sitemap_index_content),
          filename: 'sitemap_index.xml.gz',
          content_type: 'application/gzip'
        )
      end
    end

    trait :english do
      locale { 'en' }
    end

    trait :spanish do
      locale { 'es' }
    end

    trait :french do
      locale { 'fr' }
    end

    trait :ukrainian do
      locale { 'uk' }
    end
  end
end

# Helper module for generating test sitemap content
module BetterTogether
  module SitemapFactory
    module_function

    # Helper method to generate compressed sitemap content
    # rubocop:disable Metrics/MethodLength
    def gzipped_sitemap_content
      require 'zlib'
      sitemap_xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
          <url>
            <loc>https://example.com/</loc>
            <lastmod>#{Time.current.iso8601}</lastmod>
            <changefreq>daily</changefreq>
            <priority>1.0</priority>
          </url>
        </urlset>
      XML

      string_io = StringIO.new
      gz = Zlib::GzipWriter.new(string_io)
      gz.write(sitemap_xml)
      gz.close
      string_io.string
    end
    # rubocop:enable Metrics/MethodLength

    # Helper method to generate compressed sitemap index content
    # rubocop:disable Metrics/MethodLength
    def gzipped_sitemap_index_content
      require 'zlib'
      sitemap_index_xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
          <sitemap>
            <loc>https://example.com/en/sitemap.xml.gz</loc>
            <lastmod>#{Time.current.iso8601}</lastmod>
          </sitemap>
          <sitemap>
            <loc>https://example.com/es/sitemap.xml.gz</loc>
            <lastmod>#{Time.current.iso8601}</lastmod>
          </sitemap>
        </sitemapindex>
      XML

      string_io = StringIO.new
      gz = Zlib::GzipWriter.new(string_io)
      gz.write(sitemap_index_xml)
      gz.close
      string_io.string
    end
    # rubocop:enable Metrics/MethodLength
  end
end
