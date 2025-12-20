# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metrics Reports Filters', :as_platform_manager, :js do
  let(:locale) { I18n.default_locale }

  before do
    # Create some test data
    create(:metrics_page_view, page_url: 'https://example.com/page1', locale: 'en', viewed_at: 5.days.ago.change(hour: 9))
    create(:metrics_page_view, page_url: 'https://example.com/page2', locale: 'es', viewed_at: 5.days.ago.change(hour: 14))
  end

  describe 'datetime filter UI' do
    it 'displays datetime filter for each chart' do
      visit "/#{locale}/host/metrics/reports"

      within('#pageviews-charts') do
        # Should have datetime filter for page views by URL chart
        expect(page).to have_css('[data-controller="better-together--metrics-datetime-filter"]', count: 2)
        expect(page).to have_content(I18n.t('better_together.metrics.filters.datetime.title'))
      end
    end

    it 'shows correct default date range (last 30 days)' do
      visit "/#{locale}/host/metrics/reports"

      within('#pageviews-charts') do
        start_input = first('input[data-better-together--metrics-datetime-filter-target="startDate"]')
        end_input = first('input[data-better-together--metrics-datetime-filter-target="endDate"]')

        # Verify dates are set (actual values are set by JavaScript)
        expect(start_input.value).to be_present
        expect(end_input.value).to be_present
      end
    end

    it 'has apply and reset buttons' do
      visit "/#{locale}/host/metrics/reports"

      within('#pageviews-charts') do
        expect(page).to have_button(I18n.t('better_together.metrics.filters.datetime.apply'))
        expect(page).to have_button(I18n.t('better_together.metrics.filters.datetime.reset'))
      end
    end
  end

  describe 'additional filters UI' do
    it 'displays additional filters for page view charts' do
      visit "/#{locale}/host/metrics/reports"

      within('#pageviews-charts') do
        # Should have additional filters
        expect(page).to have_css('[data-controller="better-together--metrics-additional-filters"]')
        expect(page).to have_content(I18n.t('better_together.metrics.filters.additional.title'))
      end
    end

    it 'shows all filter dropdowns' do
      visit "/#{locale}/host/metrics/reports"

      within('#pageviews-charts') do
        # Locale filter
        expect(page).to have_select(
          I18n.t('better_together.metrics.filters.additional.locale'),
          with_options: [
            I18n.t('better_together.metrics.filters.additional.all_locales'),
            I18n.t('locales.en'),
            I18n.t('locales.es')
          ]
        )

        # Content type filter
        expect(page).to have_select(
          I18n.t('better_together.metrics.filters.additional.content_type'),
          with_options: [
            I18n.t('better_together.metrics.filters.additional.all_types')
          ]
        )

        # Hour of day filter
        expect(page).to have_select(
          I18n.t('better_together.metrics.filters.additional.hour_of_day'),
          with_options: [
            I18n.t('better_together.metrics.filters.additional.all_hours')
          ]
        )

        # Day of week filter
        expect(page).to have_select(
          I18n.t('better_together.metrics.filters.additional.day_of_week'),
          with_options: [
            I18n.t('better_together.metrics.filters.additional.all_days')
          ]
        )
      end
    end

    it 'has apply and reset buttons for additional filters' do
      visit "/#{locale}/host/metrics/reports"

      within('#pageviews-charts') do
        expect(page).to have_button(I18n.t('better_together.metrics.filters.additional.apply'))
        expect(page).to have_button(I18n.t('better_together.metrics.filters.additional.reset'))
      end
    end
  end

  describe 'filter accessibility' do
    it 'has proper ARIA labels and form labels' do
      visit "/#{locale}/host/metrics/reports"

      within('#pageviews-charts') do
        # Check that all form controls have labels
        expect(page).to have_css('label[for$="_start_date"]')
        expect(page).to have_css('label[for$="_end_date"]')
        expect(page).to have_css('label[for$="_locale_filter"]')
        expect(page).to have_css('label[for$="_pageable_type_filter"]')
        expect(page).to have_css('label[for$="_hour_filter"]')
        expect(page).to have_css('label[for$="_day_of_week_filter"]')
      end
    end

    it 'has help text for datetime inputs' do
      visit "/#{locale}/host/metrics/reports"

      within('#pageviews-charts') do
        expect(page).to have_content(I18n.t('better_together.metrics.filters.datetime.start_date_help'))
        expect(page).to have_content(I18n.t('better_together.metrics.filters.datetime.end_date_help'))
      end
    end
  end

  describe 'responsive design' do
    it 'uses Bootstrap grid classes for layout' do
      visit "/#{locale}/host/metrics/reports"

      within('#pageviews-charts') do
        # Datetime filter should use Bootstrap columns
        expect(page).to have_css('.col-md-4', minimum: 2)

        # Additional filters should use Bootstrap columns
        expect(page).to have_css('.col-md-3', minimum: 1)
      end
    end
  end
end
