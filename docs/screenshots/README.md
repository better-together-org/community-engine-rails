# Automated Documentation Screenshots

This directory contains guidance and tools to generate screenshots for the project documentation using Capybara + Selenium.

Overview
- A lightweight screenshot engine is provided at `spec/support/capybara_screenshot_engine.rb`.
- Specs that live under `spec/docs_screenshots/` (tagged with `:docs_screenshot`) are used to perform the actions needed to generate screenshots.
- Screenshots are saved under `docs/screenshots/desktop` and `docs/screenshots/mobile`.

How it works
- Write a feature spec that uses `BetterTogether::CapybaraScreenshotEngine.capture(name, device: :desktop|:mobile) do ... end`.
- Inside the block use Capybara DSL (visit, click_link, fill_in, etc.) to reach the state you want captured.

Running
Use Rake to run only the screenshot specs:

```bash
bin/dc-run rake docs:screenshots
```

Notes
- The task runs RSpec examples under `spec/docs_screenshots`. Ensure the dummy app or host app is running if needed (see `Capybara.asset_host`).
- ChromeDriver / Selenium is required in the environment. Install `chromedriver` and ensure `selenium-webdriver` gem is available (it's in the `:test` group).
