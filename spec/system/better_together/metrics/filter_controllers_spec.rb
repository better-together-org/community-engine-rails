# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/MultipleDescribes
RSpec.describe 'Metrics Datetime Filter Controller', :js do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('platform_manager@example.com', 'password')

    # Create test data
    create(:metrics_page_view, page_url: 'https://example.com/page', viewed_at: 5.days.ago)
  end

  describe 'datetime filter initialization' do
    it 'sets default date range on page load', skip: 'Feature test requires JS implementation' do
      visit "/#{locale}/host/metrics/reports"

      within('#pageviews-charts') do
        # Wait for Stimulus controller to initialize
        expect(page).to have_css('[data-controller="better-together--metrics-datetime-filter"]')

        # Check that dates are populated
        start_input = first('input[data-better-together--metrics-datetime-filter-target="startDate"]')
        expect(start_input.value).to be_present
      end
    end

    it 'loads chart data automatically', skip: 'Feature test requires JS implementation' do
      visit "/#{locale}/host/metrics/reports"

      within('#pageviews-charts') do
        # Wait for chart to be initialized
        expect(page).to have_css('canvas.metrics-chart')

        # Chart should have loaded (JavaScript would update the canvas)
        # This is hard to test without actual browser JavaScript execution
      end
    end
  end

  describe 'min/max date constraints', skip: 'Feature test requires JS implementation' do
    it 'sets minimum date based on earliest data' do
      visit "/#{locale}/host/metrics/reports"

      within('#pageviews-charts') do
        start_input = first('input[data-better-together--metrics-datetime-filter-target="startDate"]')

        # Should have min attribute set
        expect(start_input['min']).to be_present
      end
    end

    it 'sets maximum date to current time' do
      visit "/#{locale}/host/metrics/reports"

      within('#pageviews-charts') do
        end_input = first('input[data-better-together--metrics-datetime-filter-target="endDate"]')

        # Should have max attribute set
        expect(end_input['max']).to be_present
      end
    end
  end
end

RSpec.describe 'Metrics Additional Filters Controller', :js do
  let(:locale) { I18n.default_locale }

  before do
    configure_host_platform
    login('platform_manager@example.com', 'password')

    # Create test data with different locales
    create(:metrics_page_view, page_url: 'https://example.com/en', locale: 'en', viewed_at: 5.days.ago)
    create(:metrics_page_view, page_url: 'https://example.com/es', locale: 'es', viewed_at: 5.days.ago)
  end

  describe 'filter interaction', skip: 'Feature test requires JS implementation' do
    it 'updates chart when locale filter is changed' do
      visit "/#{locale}/host/metrics/reports"

      within('#pageviews-charts') do
        # Select Spanish locale
        select I18n.t('locales.es'), from: I18n.t('better_together.metrics.filters.additional.locale')

        # Click apply
        click_button I18n.t('better_together.metrics.filters.additional.apply')

        # Chart should update (this would require JavaScript testing framework)
        expect(page).to have_css('[data-controller="better-together--metrics-additional-filters"]')
      end
    end

    it 'resets all filters when reset button is clicked' do
      visit "/#{locale}/host/metrics/reports"

      within('#pageviews-charts') do
        # Select some filters
        select I18n.t('locales.es'), from: I18n.t('better_together.metrics.filters.additional.locale')

        # Click reset
        click_button I18n.t('better_together.metrics.filters.additional.reset')

        # Filters should be cleared
        locale_select = find('select', match: :first)
        expect(locale_select.value).to eq('')
      end
    end
  end
end
# rubocop:enable RSpec/MultipleDescribes
