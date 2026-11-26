# frozen_string_literal: true

# Capybara 3.40's Chrome reset! ends with Storage.clearDataForOrigin(origin: '*'). Chrome 158 rejects
# '*' ("invalid argument: * is not a valid URL"), so every browser example after the first one
# fails in reset. Clear the page's own origin before the reset navigates away, and skip the
# wildcard call when Chrome refuses it. Remove once Capybara ships a fix.
require 'capybara/selenium/driver'
require 'capybara/selenium/driver_specializations/chrome_driver'

module CapybaraChromeResetCompat
  def reset!
    clear_current_origin_storage
    super
  end

  def execute_cdp(cmd, params = {})
    super
  rescue Selenium::WebDriver::Error::InvalidArgumentError
    raise unless cmd == 'Storage.clearDataForOrigin' && params[:origin] == '*'

    nil
  end

  private

  def clear_current_origin_storage
    return unless @browser

    url = current_url
    return if url.nil? || url.start_with?('about:')

    uri = URI.parse(url)
    origin = "#{uri.scheme}://#{uri.host}#{":#{uri.port}" unless uri.port == uri.default_port}"
    execute_cdp('Storage.clearDataForOrigin', origin: origin, storageTypes: storage_types_to_clear)
  rescue StandardError
    nil
  end
end

Capybara::Selenium::Driver::ChromeDriver.prepend(CapybaraChromeResetCompat)
