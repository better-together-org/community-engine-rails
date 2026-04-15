# frozen_string_literal: true

require 'capybara'
require 'fileutils'
require 'json'
require 'uri'

module BetterTogether # :nodoc:
  # Captures deterministic desktop and mobile screenshots for documentation specs.
  # rubocop:disable Metrics/ModuleLength
  module CapybaraScreenshotEngine # :nodoc:
    extend self

    class CalloutTargetResolutionError < StandardError; end

    SCREENSHOT_ROOT = BetterTogether::Engine.root.join('docs', 'screenshots').freeze

    def capture(name, device: :both, metadata: {}, callouts: [], &)
      register_drivers

      devices_for(device).to_h do |current_device|
        [current_device, capture_single(name, current_device, metadata:, callouts:, &)]
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
    def capture_single(name, device, metadata:, callouts:)
      directory = SCREENSHOT_ROOT.join(device.to_s)
      FileUtils.mkdir_p(directory)

      filename = sanitize_filename(name)
      image_path = directory.join("#{filename}.png")
      json_path = directory.join("#{filename}.json")

      Capybara.using_driver(driver_for(device)) do
        Capybara.reset_sessions!

        yield if block_given?
        hide_sticky_elements
        processed_metadata = default_metadata(name, device).merge(metadata)
        callout_targets = collect_callout_targets(callouts)
        Capybara.page.save_screenshot(image_path.to_s)
        normalize_artifact_permissions(image_path)
        if callout_targets.any?
          processed_callouts = BetterTogether::ScreenshotCalloutProcessor.process(
            image_path,
            callouts: callout_targets
          )
          if processed_callouts.size != callout_targets.size
            raise CalloutTargetResolutionError,
                  "Declared #{callout_targets.size} screenshot callout(s), rendered #{processed_callouts.size}"
          end

          processed_metadata[:callouts] = processed_callouts
        end
        File.write(json_path, JSON.pretty_generate(processed_metadata))
        normalize_artifact_permissions(json_path)
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
        url: safe_page_value { normalize_page_url(Capybara.page.current_url) },
        title: safe_page_value { Capybara.page.title }
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

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def collect_callout_targets(callouts)
      normalized = Array(callouts).map { |callout| normalize_callout(callout) }.reject { |callout| callout[:selector].blank? }
      return [] if normalized.empty?

      geometry_by_selector = fetch_callout_geometry(normalized)
      missing_selectors = normalized.map { |callout| callout[:selector] } - geometry_by_selector.keys
      if missing_selectors.any?
        raise CalloutTargetResolutionError,
              "Could not resolve screenshot callout target(s): #{missing_selectors.join(', ')}"
      end

      normalized.filter_map do |callout|
        geometry = geometry_by_selector[callout[:selector]]
        next unless geometry

        callout.merge(target: geometry[:target], avoid: geometry[:avoid])
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def normalize_callout(callout)
      {
        selector: callout_value(callout, :selector),
        title: callout_value(callout, :title),
        bullets: Array(callout_value(callout, :bullets)).map(&:to_s),
        avoid_container_selector: callout_value(callout, :avoid_container_selector),
        avoid_selectors: Array(callout_value(callout, :avoid_selectors)).map(&:to_s)
      }
    end

    def callout_value(callout, key)
      callout[key] || callout[key.to_s]
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def fetch_callout_geometry(callouts)
      results = Capybara.page.evaluate_script(<<~JS, callouts)
        (function(targetCallouts) {
          function visibleRect(candidate) {
            if (!candidate) return null;
            const rect = candidate.getBoundingClientRect();
            if (rect.width <= 0 || rect.height <= 0) return null;

            return {
              x: rect.left,
              y: rect.top,
              width: rect.width,
              height: rect.height
            };
          }

          function unionRects(rects) {
            const visibleRects = rects.filter(Boolean);
            if (!visibleRects.length) return null;

            const left = Math.min(...visibleRects.map((rect) => rect.x));
            const top = Math.min(...visibleRects.map((rect) => rect.y));
            const right = Math.max(...visibleRects.map((rect) => rect.x + rect.width));
            const bottom = Math.max(...visibleRects.map((rect) => rect.y + rect.height));

            return {
              x: left,
              y: top,
              width: right - left,
              height: bottom - top
            };
          }

          function firstVisibleTarget(element) {
            const candidates = [
              element,
              element?.nextElementSibling,
              element?.previousElementSibling,
              element?.parentElement?.querySelector('.ss-main, .ts-wrapper, [role="combobox"]')
            ].filter(Boolean);

            return candidates.find((candidate) => visibleRect(candidate)) || element;
          }

          return targetCallouts.map((callout) => {
            const element = document.querySelector(callout.selector);
            if (!element) return null;
            const visibleTarget = firstVisibleTarget(element);
            const targetRect = visibleRect(visibleTarget);
            if (!targetRect) return null;
            const avoidContainer = callout.avoid_container_selector
              ? visibleTarget.closest(callout.avoid_container_selector)
              : null;
            const relatedRects = (callout.avoid_selectors || []).flatMap((selector) =>
              Array.from(document.querySelectorAll(selector)).map((candidate) => visibleRect(candidate))
            );
            const avoidRect = unionRects([
              visibleRect(avoidContainer || visibleTarget),
              ...relatedRects
            ]) || targetRect;
            return {
              selector: callout.selector,
              target: targetRect,
              avoid: avoidRect
            };
          }).filter(Boolean);
        })(arguments[0]);
      JS

      Array(results).to_h do |geometry|
        selector = geometry['selector'] || geometry[:selector]
        [
          selector,
          {
            target: {
              x: geometry.dig('target', 'x') || geometry.dig(:target, :x),
              y: geometry.dig('target', 'y') || geometry.dig(:target, :y),
              width: geometry.dig('target', 'width') || geometry.dig(:target, :width),
              height: geometry.dig('target', 'height') || geometry.dig(:target, :height)
            },
            avoid: {
              x: geometry.dig('avoid', 'x') || geometry.dig(:avoid, :x),
              y: geometry.dig('avoid', 'y') || geometry.dig(:avoid, :y),
              width: geometry.dig('avoid', 'width') || geometry.dig(:avoid, :width),
              height: geometry.dig('avoid', 'height') || geometry.dig(:avoid, :height)
            }
          }
        ]
      end
    rescue StandardError => e
      raise CalloutTargetResolutionError, "Failed to resolve screenshot callout geometry: #{e.message}"
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    def normalize_page_url(url)
      return if url.blank?

      uri = URI.parse(url)
      path = uri.path.presence || '/'
      uri.query.present? ? "#{path}?#{uri.query}" : path
    rescue URI::InvalidURIError
      url.to_s.sub(%r{\Ahttps?://[^/]+}, '')
    end

    def normalize_artifact_permissions(path)
      File.chmod(0o644, path.to_s) if File.exist?(path)
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

          const preserveFixedElement = (element) => {
            if (!element || !element.matches) return false;

            return element.matches('.modal.show, .modal-backdrop.show, .modal-backdrop.fade.show') ||
              !!element.closest('.modal.show');
          };

          document.querySelectorAll('*').forEach((element) => {
            const computed = window.getComputedStyle(element);
            if ((computed.position === 'fixed' || computed.position === 'sticky') && !preserveFixedElement(element)) {
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
