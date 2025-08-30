# frozen_string_literal: true

require 'fileutils'
require 'capybara'
require 'json'
begin
  require 'vips'
  VIPS_AVAILABLE = true
rescue LoadError
  VIPS_AVAILABLE = false
end

# Lightweight screenshot engine for documentation.
# Provides helpers to capture desktop and mobile screenshots using Selenium/Chrome.
module BetterTogether
  module CapybaraScreenshotEngine
    extend self

    SCREENSHOT_DIR = BetterTogether::Engine.root.join('docs', 'screenshots').to_s.freeze

    # Register drivers for desktop and mobile emulation.
    def register_drivers
      return if @registered

      # Desktop 1920x1080
      Capybara.register_driver :selenium_chrome_headless_1920 do |app|
        options = ::Selenium::WebDriver::Chrome::Options.new
        options.add_argument('--headless=new') if Selenium::WebDriver::VERSION >= '4'
        options.add_argument('--disable-gpu')
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--window-size=1920,1080')
        Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
      end

      # Mobile (approx iPhone X viewport)
      Capybara.register_driver :selenium_chrome_headless_mobile do |app|
        options = ::Selenium::WebDriver::Chrome::Options.new
        options.add_argument('--headless=new') if Selenium::WebDriver::VERSION >= '4'
        options.add_argument('--disable-gpu')
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--window-size=375,812')
        Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
      end

      @registered = true
    end

  # Capture a screenshot by running the provided actions block.
  # By default captures both :desktop and :mobile orientations unless a specific device is passed.
  # name - base filename (no extension)
  # device - :desktop, :mobile, or :both (default :both)
  # Options (kwargs):
  # - selector: CSS selector to crop to (optional)
  # - stitch: true/false to attempt full-page stitching (basic)
  # - metadata: hash of extra metadata to write alongside the image
  # Returns: filename string for single device, or a Hash { device => filename } when both
  def capture(name, device: :both, format: :png, selector: nil, stitch: false, metadata: {}, &action)
    register_drivers

    devices = case device
              when :both, nil
                [:desktop, :mobile]
              else
                Array(device).map(&:to_sym)
              end

    results = {}
    devices.each do |dev|
      results[dev] = perform_capture_single(name, dev, format: format, selector: selector, stitch: stitch, metadata: metadata, &action)
    end

    return results[devices.first] if devices.length == 1
    results
  end

  private

  def perform_capture_single(name, device, format: :png, selector: nil, stitch: false, metadata: {}, &action)
  driver = device == :mobile ? :selenium_chrome_headless_mobile : :selenium_chrome_headless_1920

    FileUtils.mkdir_p(target_dir(device))

    previous_driver = Capybara.current_driver
    Capybara.current_driver = driver

    begin
      # Allow caller to perform actions using Capybara DSL
      action.call if action

      # Hide sticky/fixed elements to avoid overlays in screenshots
      hide_sticky_elements

      filename = File.join(target_dir(device), "#{sanitize_filename(name)}.#{format}")

      # Save a screenshot to a temporary directory first
      tmpdir = Dir.mktmpdir
      tmpfile = File.join(tmpdir, File.basename(filename))
      if Capybara.page.respond_to?(:save_screenshot)
        Capybara.page.save_screenshot(tmpfile)
      else
        Capybara.save_screenshot(tmpfile)
      end

  final_path = tmpfile

      if stitch && VIPS_AVAILABLE
        begin
          stitched = stitch_full_page(filename, device)
          final_path = stitched if stitched
        rescue StandardError => e
          puts "Full-page stitching failed: #{e.message}, using viewport screenshot"
        end
      end

    if selector && VIPS_AVAILABLE
        begin
      crop_to_selector(final_path, selector)
        rescue StandardError => e
          puts "Crop to selector failed: #{e.message}"
        end
      end

      # Move final image into target location if it is different
      if final_path != filename
        FileUtils.mv(final_path, filename)
      else
        FileUtils.mv(tmpfile, filename)
      end
      FileUtils.rm_rf(tmpdir)

      # Write metadata sidecar (JSON)
      meta = { name: name, device: device.to_s, url: (Capybara.current_url rescue nil), title: (Capybara.page.title rescue nil), created_at: Time.now.utc.iso8601 }.merge(metadata)
      File.write(filename.sub(/\.[^.]+$/, '.json'), JSON.pretty_generate(meta))

      puts "Saved documentation screenshot: #{filename}"

      filename
    ensure
      # restore any sticky elements we hid
      restore_sticky_elements
      Capybara.current_driver = previous_driver
    end
  end

    def target_dir(device)
      File.join(SCREENSHOT_DIR, device.to_s)
    end

    def sanitize_filename(name)
      name.to_s.downcase.gsub(%r{[^0-9a-z._-]}, '_')
    end

    # Attempt a basic full-page stitch by scrolling the page and taking viewport screenshots,
    # then combining them vertically with ruby-vips. Returns path to stitched image or nil.
    def stitch_full_page(filename, device)
      return nil unless VIPS_AVAILABLE

      view_height = (device == :mobile ? 812 : 1080)
      total_height = Capybara.evaluate_script('document.body.scrollHeight') rescue nil
      return nil unless total_height && total_height > view_height

      tmpdir = Dir.mktmpdir
      parts = []
      offset = 0
      index = 0
      while offset < total_height
        Capybara.execute_script("window.scrollTo(0, #{offset});")
        sleep 0.2
        part_file = File.join(tmpdir, "part_#{index}.png")
        if Capybara.page.respond_to?(:save_screenshot)
          Capybara.page.save_screenshot(part_file)
        else
          Capybara.save_screenshot(part_file)
        end
        parts << part_file
        index += 1
        offset += view_height
      end

      # Use Vips to append images vertically
      imgs = parts.map { |p| Vips::Image.new_from_file(p) }
      stitched = Vips::Image.arrayjoin(imgs, across: 1)
      stitched.write_to_file(filename)

      FileUtils.rm_rf(tmpdir)
      filename
    end

    # Crop image file to bounding rect of selector using page coordinates and vips.
    def crop_to_selector(image_path, selector)
      return unless VIPS_AVAILABLE
      rect = Capybara.evaluate_script(<<~JS)
        (function(){
          var el = document.querySelector(#{selector.to_json});
          if(!el) return null;
          var r = el.getBoundingClientRect();
          return { x: r.left, y: r.top, w: r.width, h: r.height, dpr: window.devicePixelRatio || 1 };
        })()
      JS

      return unless rect && rect['w'] > 0 && rect['h'] > 0

      # Multiply CSS pixels by devicePixelRatio to get actual image pixels
      dpr = (rect['dpr'] || 1).to_f
      x = (rect['x'] * dpr).to_i
      y = (rect['y'] * dpr).to_i
      w = (rect['w'] * dpr).to_i
      h = (rect['h'] * dpr).to_i

      img = Vips::Image.new_from_file(image_path)
      # Clamp crop box to image bounds
      w = [w, img.width - x].min
      h = [h, img.height - y].min
      return if w <= 0 || h <= 0
      cropped = img.crop(x, y, w, h)
      cropped.write_to_file(image_path)
    end

    # Hide elements with position fixed or sticky by adding a class and injecting a style rule.
    def hide_sticky_elements
      Capybara.execute_script(<<~JS)
        (function(){
          if(window.__bt_screenshot_hidden_applied__) return;
          var style = document.createElement('style');
          style.id = '__bt_screenshot_hide_style__';
          style.type = 'text/css';
          style.innerHTML = '.__bt_screenshot_hidden__{visibility:hidden !important; pointer-events:none !important; opacity:0 !important}';
          document.head.appendChild(style);
          var els = [];
          document.querySelectorAll('*').forEach(function(el){
            try{
              var s = window.getComputedStyle(el);
              if(s && (s.position === 'fixed' || s.position === 'sticky')){
                el.classList.add('__bt_screenshot_hidden__');
                els.push(el);
              }
            }catch(e){}
          });
          window.__bt_screenshot_hidden_applied__ = true;
        })();
      JS
    end

    # Restore previously hidden sticky elements
    def restore_sticky_elements
      Capybara.execute_script(<<~JS)
        (function(){
          if(!window.__bt_screenshot_hidden_applied__) return;
          document.querySelectorAll('.__bt_screenshot_hidden__').forEach(function(el){
            el.classList.remove('__bt_screenshot_hidden__');
          });
          var s = document.getElementById('__bt_screenshot_hide_style__');
          if(s) s.parentNode.removeChild(s);
          window.__bt_screenshot_hidden_applied__ = false;
        })();
      JS
    end
  end
end
