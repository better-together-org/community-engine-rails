# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :metrics do
  desc 'Seed sample metrics data for testing filters'
  task seed: :environment do
    puts 'Creating sample metrics data...'

    # Get real page paths from existing pages
    # Pages use Mobility for translated slugs, so we need to get them per locale
    page_paths = []
    I18n.available_locales.each do |locale|
      Mobility.with_locale(locale) do
        BetterTogether::Page.published.find_each do |page|
          page_paths << "/#{locale}/#{page.slug}" if page.slug.present?
        end
      end
    end

    # Also add root-level identifiers as fallback
    BetterTogether::Page.pluck(:identifier).each do |identifier|
      page_paths << "/#{identifier}"
    end

    page_paths.uniq!

    # Fallback to sample paths if no pages exist
    if page_paths.empty?
      page_paths = [
        '/about',
        '/contact',
        '/events',
        '/events/test',
        '/en/cbts',
        '/en/about',
        '/home',
        '/c/test'
      ]
      puts '⚠️  No pages found in database, using sample paths'
    else
      puts "✅ Found #{page_paths.count} page paths to use for metrics"
    end

    # Create page views with different locales
    I18n.available_locales.each do |locale|
      10.times do
        BetterTogether::Metrics::PageView.create!(
          page_url: page_paths.sample,
          locale: locale.to_s,
          viewed_at: Faker::Time.between(from: 30.days.ago, to: Time.current)
        )
      end
      puts "Created 10 page views for locale: #{locale}"
    end

    # Create page views for different hours of the day
    (0..23).each do |hour|
      3.times do
        time = Faker::Time.between(from: 30.days.ago, to: Time.current)
        time = time.change(hour: hour)

        BetterTogether::Metrics::PageView.create!(
          page_url: page_paths.sample,
          locale: I18n.available_locales.sample.to_s,
          viewed_at: time
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

        BetterTogether::Metrics::PageView.create!(
          page_url: page_paths.sample,
          locale: I18n.available_locales.sample.to_s,
          viewed_at: time
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
# rubocop:enable Metrics/BlockLength
