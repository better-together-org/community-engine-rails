# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :better_together do
  namespace :metrics do
    desc 'Seed sample metrics data for testing and demonstration'
    task seed: :environment do
      puts '🔢 Seeding metrics data...'

      # Find or create sample pages to use as pageables
      sample_pages = []
      I18n.with_locale(:en) do
        3.times do |i|
          page = BetterTogether::Page.find_or_create_by!(identifier: "sample-page-#{i + 1}") do |p|
            p.title = "Sample Page #{i + 1}"
            p.content = "Sample content for page #{i + 1}"
            p.privacy = 'public'
            p.published_at = Time.current
          end

          sample_pages << page
        end
      end

      # Get real pages from the database to use as additional pageables
      pages_by_locale = {}
      I18n.available_locales.each do |locale|
        pages_by_locale[locale] = []
        Mobility.with_locale(locale) do
          BetterTogether::Page.published.find_each do |page|
            pages_by_locale[locale] << page if page.slug.present?
          end
        end
      end

      # Get all pages as fallback
      all_pages = BetterTogether::Page.all.to_a

      puts "✅ Found #{all_pages.count} pages to use for metrics"

      # Seed Page Views with various patterns
      puts '  📊 Creating page views...'
      locales = I18n.available_locales.map(&:to_s)

      # Create page views with time distribution
      [30, 15, 7, 3, 1].each do |days_ago|
        date = days_ago.days.ago

        # Vary the number of views per day (more recent = more views)
        views_count = (35 - days_ago) * rand(2..5)

        views_count.times do
          page = all_pages.sample
          locale = locales.sample

          page_url = Mobility.with_locale(locale) do
            page.slug.present? ? "/#{locale}/#{page.slug}" : "/#{page.identifier}"
          end

          BetterTogether::Metrics::PageView.create!(
            pageable: page,
            page_url: page_url,
            locale: locale,
            viewed_at: date + rand(0..23).hours + rand(0..59).minutes
          )
        end
      end

      # Create page views for different hours of the day
      (0..23).each do |hour|
        3.times do
          time = Faker::Time.between(from: 30.days.ago, to: Time.current)
          time = time.change(hour: hour)
          page = all_pages.sample
          locale = locales.sample

          page_url = Mobility.with_locale(locale) do
            page.slug.present? ? "/#{locale}/#{page.slug}" : "/#{page.identifier}"
          end

          BetterTogether::Metrics::PageView.create!(
            page_url: page_url,
            locale: locale,
            viewed_at: time,
            pageable: page
          )
        end
      end

      # Create page views for different days of the week
      (0..6).each do |day_of_week|
        5.times do
          # Find a date with this day of week within the last 30 days
          date = 30.days.ago.to_date
          date += 1.day while date.wday != day_of_week

          time = Faker::Time.between(from: date.to_time, to: date.end_of_day)
          page = all_pages.sample
          locale = locales.sample

          page_url = Mobility.with_locale(locale) do
            page.slug.present? ? "/#{locale}/#{page.slug}" : "/#{page.identifier}"
          end

          BetterTogether::Metrics::PageView.create!(
            page_url: page_url,
            locale: locale,
            viewed_at: time,
            pageable: page
          )
        end
      end

      # Seed Link Clicks
      puts '  🔗 Creating link clicks...'
      [30, 15, 7, 3, 1].each do |days_ago|
        date = days_ago.days.ago

        clicks_count = (20 - (days_ago / 2)) * rand(1..3)

        clicks_count.times do
          page = all_pages.sample
          locale = locales.sample

          page_url = Mobility.with_locale(locale) do
            page.slug.present? ? "/#{locale}/#{page.slug}" : "/#{page.identifier}"
          end

          BetterTogether::Metrics::LinkClick.create!(
            url: "https://external-site.com/page-#{rand(1..10)}",
            page_url: page_url,
            locale: locale,
            internal: [true, false].sample,
            clicked_at: date + rand(0..23).hours + rand(0..59).minutes
          )
        end
      end

      # Seed Downloads
      puts '  💾 Creating downloads...'
      file_types = %w[pdf docx xlsx zip]
      file_names = ['report.pdf', 'document.docx', 'spreadsheet.xlsx', 'archive.zip']

      [30, 15, 7, 3, 1].each do |days_ago|
        date = days_ago.days.ago

        downloads_count = (15 - (days_ago / 3)) * rand(1..2)

        downloads_count.times do
          file_type = file_types.sample
          BetterTogether::Metrics::Download.create!(
            downloadable: all_pages.sample,
            file_name: file_names.sample,
            file_type: file_type,
            file_size: rand(100_000..10_000_000),
            locale: locales.sample,
            downloaded_at: date + rand(0..23).hours + rand(0..59).minutes
          )
        end
      end

      # Seed Shares
      puts '  📤 Creating shares...'
      platforms = BetterTogether::Metrics::Share::SHAREABLE_PLATFORMS

      [30, 15, 7, 3, 1].each do |days_ago|
        date = days_ago.days.ago

        shares_count = (10 - (days_ago / 4)) * rand(1..2)

        shares_count.times do
          page = all_pages.sample
          locale = locales.sample

          page_url = Mobility.with_locale(locale) do
            page.slug.present? ? "https://example.com/#{locale}/#{page.slug}" : "https://example.com/#{page.identifier}"
          end

          BetterTogether::Metrics::Share.create!(
            shareable: page,
            platform: platforms.sample,
            url: page_url,
            locale: locale,
            shared_at: date + rand(0..23).hours + rand(0..59).minutes
          )
        end
      end

      puts '✅ Metrics seeding complete!'
      puts "  - Page Views: #{BetterTogether::Metrics::PageView.count}"
      puts "  - Link Clicks: #{BetterTogether::Metrics::LinkClick.count}"
      puts "  - Downloads: #{BetterTogether::Metrics::Download.count}"
      puts "  - Shares: #{BetterTogether::Metrics::Share.count}"
    end
  end
end
# rubocop:enable Metrics/BlockLength
