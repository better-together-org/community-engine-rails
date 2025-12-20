# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :better_together do
  namespace :metrics do
    desc 'Seed sample metrics data for testing filters'
    task seed: :environment do
      puts 'Creating sample metrics data...'

      # Get real pages from the database to use as pageables
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

      if all_pages.empty?
        puts '⚠️  No pages found in database. Please create some pages first.'
        puts 'You can create pages through the UI or by running: rails db:seed'
        exit
      end

      puts "✅ Found #{all_pages.count} pages to use for metrics"

      # Create page views with different locales
      I18n.available_locales.each do |locale|
        locale_pages = pages_by_locale[locale]
        locale_pages = all_pages if locale_pages.empty?

        10.times do
          page = locale_pages.sample
          # Build the page URL from the page's slug in this locale
          page_url = Mobility.with_locale(locale) do
            page.slug.present? ? "/#{locale}/#{page.slug}" : "/#{page.identifier}"
          end

          BetterTogether::Metrics::PageView.create!(
            page_url: page_url,
            locale: locale.to_s,
            viewed_at: Faker::Time.between(from: 30.days.ago, to: Time.current),
            pageable: page
          )
        end
        puts "Created 10 page views for locale: #{locale}"
      end

      # Create page views for different hours of the day
      (0..23).each do |hour|
        3.times do
          time = Faker::Time.between(from: 30.days.ago, to: Time.current)
          time = time.change(hour: hour)
          page = all_pages.sample
          locale = I18n.available_locales.sample

          page_url = Mobility.with_locale(locale) do
            page.slug.present? ? "/#{locale}/#{page.slug}" : "/#{page.identifier}"
          end

          BetterTogether::Metrics::PageView.create!(
            page_url: page_url,
            locale: locale.to_s,
            viewed_at: time,
            pageable: page
          )
        end
      end
      puts 'Created page views for all hours of the day'

      # Create page views for different days of the week
      (0..6).each do |day_of_week|
        5.times do
          # Find a date with this day of week within the last 30 days
          date = 30.days.ago.to_date
          date += 1.day while date.wday != day_of_week

          time = Faker::Time.between(from: date.to_time, to: date.end_of_day)
          page = all_pages.sample
          locale = I18n.available_locales.sample

          page_url = Mobility.with_locale(locale) do
            page.slug.present? ? "/#{locale}/#{page.slug}" : "/#{page.identifier}"
          end

          BetterTogether::Metrics::PageView.create!(
            page_url: page_url,
            locale: locale.to_s,
            viewed_at: time,
            pageable: page
          )
        end
      end
      puts 'Created page views for all days of the week'

      total = BetterTogether::Metrics::PageView.count
      puts "\n✅ Total page views in database: #{total}"
      puts 'Breakdown by locale:'
      BetterTogether::Metrics::PageView.group(:locale).count.each do |locale, count|
        puts "  #{locale}: #{count}"
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
