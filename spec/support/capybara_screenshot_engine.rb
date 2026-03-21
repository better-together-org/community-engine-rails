# frozen_string_literal: true

require 'capybara'
require 'fileutils'
require 'json'

module BetterTogether
  # Captures deterministic desktop and mobile screenshots for documentation specs.
  # rubocop:disable Metrics/ModuleLength
  module CapybaraScreenshotEngine
    extend self

    SCREENSHOT_ROOT = BetterTogether::Engine.root.join('docs', 'screenshots').freeze

    def capture(name, device: :both, metadata: {}, &)
      register_drivers

      devices_for(device).to_h do |current_device|
        [current_device, capture_single(name, current_device, metadata:, &)]
      end
    end

    private

    # rubocop:disable Metrics/MethodLength
    def register_drivers
      return if @registered

      Capybara.register_driver :selenium_chrome_headless_docs_desktop do |app|
        options = Selenium::WebDriver::Chrome::Options.new
        options.add_argument('--headless=new')
        options.add_argument('--disable-gpu')
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--window-size=1440,1600')

        Capybara::Selenium::Driver.new(app, browser: :chrome, options:)
      end

      Capybara.register_driver :selenium_chrome_headless_docs_mobile do |app|
        options = Selenium::WebDriver::Chrome::Options.new
        options.add_argument('--headless=new')
        options.add_argument('--disable-gpu')
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--window-size=430,1400')

        Capybara::Selenium::Driver.new(app, browser: :chrome, options:)
      end

      @registered = true
    end
    # rubocop:enable Metrics/MethodLength

    def devices_for(device)
      return %i[desktop mobile] if device.nil? || device.to_sym == :both

      [device.to_sym]
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def capture_single(name, device, metadata:)
      directory = SCREENSHOT_ROOT.join(device.to_s)
      FileUtils.mkdir_p(directory)

      filename = sanitize_filename(name)
      image_path = directory.join("#{filename}.png")
      json_path = directory.join("#{filename}.json")

      Capybara.using_driver(driver_for(device)) do
        Capybara.reset_sessions!

        yield if block_given?
        hide_sticky_elements
        Capybara.page.save_screenshot(image_path.to_s)
        File.write(json_path, JSON.pretty_generate(default_metadata(name, device).merge(metadata)))
      ensure
        restore_sticky_elements
      end

      image_path.to_s
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def default_metadata(name, device)
      {
        name:,
        device: device.to_s,
        url: safe_page_value { Capybara.page.current_url },
        title: safe_page_value { Capybara.page.title },
        captured_at: Time.current.utc.iso8601
      }
    end

    def driver_for(device)
      device == :mobile ? :selenium_chrome_headless_docs_mobile : :selenium_chrome_headless_docs_desktop
    end

    def sanitize_filename(name)
      name.to_s.downcase.gsub(/[^a-z0-9._-]+/, '_').gsub(/\A_+|_+\z/, '')
    end

    def safe_page_value
      yield
    rescue StandardError
      nil
    end

    # rubocop:disable Metrics/MethodLength
    def hide_sticky_elements
      Capybara.page.execute_script(<<~JS)
        (function() {
          if (window.__btDocsScreenshotHidden) return;
          const style = document.createElement('style');
          style.id = '__bt_docs_screenshot_style__';
          style.innerHTML = '.__bt_docs_screenshot_hidden__ { visibility: hidden !important; opacity: 0 !important; pointer-events: none !important; }';
          document.head.appendChild(style);

          document.querySelectorAll('*').forEach((element) => {
            const computed = window.getComputedStyle(element);
            if (computed.position === 'fixed' || computed.position === 'sticky') {
              element.classList.add('__bt_docs_screenshot_hidden__');
            }
          });

          window.__btDocsScreenshotHidden = true;
        })();
      JS
    rescue StandardError
      nil
    end
    # rubocop:enable Metrics/MethodLength

    def restore_sticky_elements
      Capybara.page.execute_script(<<~JS)
        (function() {
          if (!window.__btDocsScreenshotHidden) return;

          document.querySelectorAll('.__bt_docs_screenshot_hidden__').forEach((element) => {
            element.classList.remove('__bt_docs_screenshot_hidden__');
          });

          const style = document.getElementById('__bt_docs_screenshot_style__');
          if (style) style.remove();
          window.__btDocsScreenshotHidden = false;
        })();
      JS
    rescue StandardError
      nil
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
