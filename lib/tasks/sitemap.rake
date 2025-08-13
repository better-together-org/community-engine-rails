# frozen_string_literal: true

namespace :sitemap do
  desc 'Generate sitemap and upload to Active Storage'
  task refresh: :environment do
    require 'sitemap_generator'

    SitemapGenerator::Sitemap.public_path = Rails.root.join('tmp')
    SitemapGenerator::Sitemap.sitemaps_path = ''

    load Rails.root.join('config/sitemap.rb')

    file_path = Rails.root.join('tmp', 'sitemap.xml.gz')
    platform = BetterTogether::Platform.find_by!(host: true)
    BetterTogether::Sitemap.current(platform).file.attach(
      io: File.open(file_path),
      filename: 'sitemap.xml.gz',
      content_type: 'application/gzip'
    )
  end
end

begin
  Rake::Task['assets:precompile'].enhance do
    Rake::Task['sitemap:refresh'].invoke
  end
rescue RuntimeError
  # assets:precompile may not be defined in some environments
end
