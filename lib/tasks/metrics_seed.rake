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

      # Seed Search Queries
      puts '  🔍 Creating search queries...'

      # Common search terms by category
      search_terms = {
        general: %w[help contact about privacy terms support],
        community: %w[community members groups events discussions],
        content: %w[articles news blog resources documentation],
        actions: ['how to', 'getting started', 'tutorial', 'guide', 'faq'],
        specific: %w[employment housing healthcare education transportation],
        misspelled: %w[comunity articls emploiment helth edukation]
      }

      [30, 15, 7, 3, 1].each do |days_ago|
        date = days_ago.days.ago

        # More searches on recent days
        searches_count = (25 - (days_ago / 2)) * rand(1..3)

        searches_count.times do
          # Randomly pick a category and term
          category = search_terms.keys.sample
          query = search_terms[category].sample

          # Misspelled queries tend to have fewer results
          # Specific queries have varied results
          # General queries tend to have more results
          results_count = case category
                          when :misspelled
                            rand(0..2)
                          when :specific
                            rand(0..15)
                          when :general, :community
                            rand(5..50)
                          when :content
                            rand(3..30)
                          else
                            rand(0..20)
                          end

          locale = locales.sample

          BetterTogether::Metrics::SearchQuery.create!(
            query: query,
            results_count: results_count,
            locale: locale,
            searched_at: date + rand(0..23).hours + rand(0..59).minutes
          )
        end
      end

      # Create some multi-word searches
      multi_word_searches = [
        'how to join community',
        'find local events',
        'community guidelines',
        'member directory',
        'contact support team',
        'privacy policy updates',
        'getting started guide',
        'employment opportunities',
        'housing resources',
        'healthcare services'
      ]

      20.times do
        query = multi_word_searches.sample
        results_count = rand(0..25)
        locale = locales.sample
        searched_at = Faker::Time.between(from: 30.days.ago, to: Time.current)

        BetterTogether::Metrics::SearchQuery.create!(
          query: query,
          results_count: results_count,
          locale: locale,
          searched_at: searched_at
        )
      end

      # Create some empty searches (zero results)
      10.times do
        query = ['xyz123', 'nonexistent term', 'random gibberish', 'asdfjkl'].sample
        locale = locales.sample
        searched_at = Faker::Time.between(from: 30.days.ago, to: Time.current)

        BetterTogether::Metrics::SearchQuery.create!(
          query: query,
          results_count: 0,
          locale: locale,
          searched_at: searched_at
        )
      end

      puts '✅ Metrics seeding complete!'
      puts "  - Page Views: #{BetterTogether::Metrics::PageView.count}"
      puts "  - Link Clicks: #{BetterTogether::Metrics::LinkClick.count}"
      puts "  - Downloads: #{BetterTogether::Metrics::Download.count}"
      puts "  - Shares: #{BetterTogether::Metrics::Share.count}"
      puts "  - Search Queries: #{BetterTogether::Metrics::SearchQuery.count}"
    end
  end
end
# rubocop:enable Metrics/BlockLength
