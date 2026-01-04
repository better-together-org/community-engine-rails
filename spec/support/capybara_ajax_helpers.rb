# frozen_string_literal: true

module CapybaraAjaxHelpers
  # Wait for all pending AJAX requests to complete
  # Note: This assumes Fetch API or other async operations
  def wait_for_ajax(timeout: Capybara.default_max_wait_time)
    Timeout.timeout(timeout) do
      loop do
        # For modern apps using Fetch API, we check if document is in loading state
        loading = page.evaluate_script('document.readyState === "loading"')
        break unless loading

        sleep 0.1
      end
    end
  rescue Timeout::Error
    raise 'Timeout waiting for AJAX requests to complete'
  end

  # Wait for specific Stimulus controller to connect and be ready
  def wait_for_stimulus_controller(controller_name, timeout: 5)
    selector = "[data-controller*='#{controller_name}']"
    expect(page).to have_css(selector, wait: timeout)

    # Give the controller a moment to complete its connect() lifecycle
    sleep 0.2
  end

  # Wait for Chart.js chart to render completely
  def wait_for_chart(chart_target, timeout: 10)
    expect(page).to have_css(
      "canvas[data-better-together--metrics-charts-target='#{chart_target}']",
      wait: timeout
    )

    # Additional time for Chart.js to complete rendering
    sleep 0.5
  end

  # Wait for a specific tab pane to be visible and active
  def wait_for_tab_pane(pane_id, timeout: 10)
    selector = "##{pane_id}.show.active"
    expect(page).to have_css(selector, wait: timeout)
  end

  # Wait for Turbo to finish loading after navigation
  def wait_for_turbo_load(timeout: 10)
    Timeout.timeout(timeout) do
      loop do
        # Check if Turbo is still loading
        loading = page.evaluate_script('document.documentElement.hasAttribute("data-turbo-preview")')
        break unless loading

        sleep 0.1
      end
    end
  rescue Timeout::Error
    raise 'Timeout waiting for Turbo to finish loading'
  end

  # Combines multiple wait conditions for metrics pages with heavy JavaScript
  def wait_for_metrics_page_ready(tab_pane_id = 'pageviews-charts', timeout: 15)
    # Wait for the main container to exist
    expect(page).to have_css('.container-fluid', wait: timeout)

    # Wait for the specific tab pane
    wait_for_tab_pane(tab_pane_id, timeout:) if tab_pane_id

    # Wait for Stimulus controllers to initialize
    wait_for_stimulus_controller('better_together--metrics-charts', timeout: 5)

    # Small buffer for any remaining async operations
    sleep 0.3
  end
end

RSpec.configure do |config|
  config.include CapybaraAjaxHelpers, type: :feature
end
