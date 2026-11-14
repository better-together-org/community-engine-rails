# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/NoExpectationExample
# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_tax_display_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_orders_spec.rb and the checkout request spec.
RSpec.describe 'Documentation screenshots for the order summary with tax', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::BillingAddressHelpers

  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:metadata) do
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'billing_tax', source_spec: self.class.metadata[:file_path] }
  end
  let(:zero_rated) do
    create(:better_together_billing_tax_category, platform: host_platform, identifier: 'zero_rated', name: 'Zero rated', taxable: false)
  end
  let(:book) do
    create(:better_together_billing_plan, :unlinked, processor: nil, billing_interval: 'one_time', currency: 'CAD', amount_cents: 1500,
                                                     name: 'Printed guide', tax_category: zero_rated)
  end
  let(:membership) do
    create(:better_together_billing_plan, :unlinked, processor: nil, billing_interval: 'one_time', currency: 'CAD', amount_cents: 12_000,
                                                     name: 'Annual plan', accepted_payment_methods: %w[cash])
  end
  let(:manager) { BetterTogether::User.find_by!(email: 'manager@example.test').person }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    enable_offline('cash')
  end

  after { Current.platform = nil }

  # GST under the federal number, plus the province's own tax under its number.
  def registrations_for(region, label, rate, number)
    create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA', registration_number: '123456789RT0001')
    create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA', region_code: region,
                                                      registration_number: number)
    create(:better_together_billing_tax_rate, platform: host_platform, label: 'GST', rate: 0.05,
                                              tax_zone: create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA'))
    create(:better_together_billing_tax_rate, platform: host_platform, label:, rate:,
                                              tax_zone: create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA',
                                                                                                  region_code: region))
  end

  def place_for(region)
    place_order(buyer: manager, payment_method: 'cash', tax_address: { country_iso: 'CA', region_code: region },
                line_items: [{ purchasable: membership }, { purchasable: book }])
  end

  # Nothing runs off the screen: the page does not scroll sideways and no part of the summary reaches past the edge.
  def expect_fits_viewport(selector) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    result = page.evaluate_script(<<~JS)
      (function () {
        var edge = document.documentElement.clientWidth + 0.5;
        var wide = Array.prototype.filter.call(document.querySelectorAll(#{selector.to_json} + ', ' + #{selector.to_json} + ' *'), function (el) {
          return el.getBoundingClientRect().right > edge;
        }).map(function (el) { return el.tagName + (el.id ? '#' + el.id : '') + ' ' + Math.round(el.getBoundingClientRect().right); });
        var page = Array.prototype.filter.call(document.querySelectorAll('body *'), function (el) {
          return el.getBoundingClientRect().right > edge;
        }).slice(0, 6).map(function (el) { return el.tagName + '#' + el.id + '.' + String(el.className).slice(0, 40) + ' ' + Math.round(el.getBoundingClientRect().right); });
        return { page: page, scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth, width: window.innerWidth, wide: wide };
      })()
    JS
    expect(result['scroll']).to be <= result['client'],
                                "page scrolls sideways at #{result['width']}px (#{result['scroll']} > #{result['client']}): " \
                                "#{result['page'].join(' | ')}"
    expect(result['wide']).to be_empty, "past the right edge at #{result['width']}px: #{result['wide'].first(5).join(', ')}"
  end

  def at_width(width)
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride', width:, height: 1400, deviceScaleFactor: 1, mobile: true)
    expect(page.evaluate_script('window.innerWidth')).to eq(width)
  end

  def capture(name, target, title, bullet, path)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name, device: :both, metadata: metadata.merge(flow: name),
            callouts: [{ id: name, selector: target, title:, avoid_container_selector: 'main', bullets: [bullet] }]
    ) do
      capybara_login_as_platform_manager
      visit path
      scroll_to(find(target), align: :center)
      expect(page).to have_css(target)
      expect_fits_viewport(target)
    end
  end

  def capture_surfaces(prefix, region)
    order = place_for(region)
    offline = order.offline_payments.first
    capture("billing_tax_#{prefix}_order", '#billing-summary-order', 'Order summary',
            'A marker on each line, a row per tax, the total and the registration numbers.',
            "/#{I18n.default_locale}/billing/orders/#{order.id}")
    capture("billing_tax_#{prefix}_offline", "#billing-summary-offline-#{offline.id}", 'Same summary beside the payment instructions',
            'The figures match the order page.', "/#{I18n.default_locale}/billing/orders/#{order.id}")
    capture_email("billing_tax_#{prefix}_email", order)
  end

  # The notice email, drawn into a page of the app so the same screenshot tooling can frame it.
  def capture_email(name, order)
    html = notice_html(order)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name, device: :both, metadata: metadata.merge(flow: name),
            callouts: [{ id: name, selector: '#billing-summary-email', title: 'Notice email', avoid_container_selector: 'body',
                         bullets: ['The email carries the full summary, never payment details.'] }]
    ) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/billing/orders"
      page.execute_script('document.open(); document.write(arguments[0]); document.close();', html)
      expect(page).to have_css('#billing-summary-email')
      expect_fits_viewport('#billing-summary-email')
    end
  end

  def notice_html(order)
    notifier = BetterTogether::Billing::Notifier.new(record: order, params: { kind: 'order_paid', audience: :buyer })
    BetterTogether::BillingMailer.with(recipient: manager, notifier:).notification.html_part.body.decoded
  end

  def capture_checkout(prefix, region)
    create_billing_address_for(manager, region:, settlement_name: region)
    capture("billing_tax_#{prefix}_checkout", '#billing-summary-checkout', 'Tax before paying',
            'The same rows, for the chosen billing address.', "/#{I18n.default_locale}/billing/checkout/new?plan_id=#{membership.id}")
  end

  # Phone widths, with long names and long numbers: it wraps, nothing is clipped, the page does not scroll sideways.
  def expect_surfaces_fit(order, widths) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    BetterTogether::CapybaraScreenshotEngine.send(:register_drivers)
    Capybara.using_driver(:selenium_chrome_headless_docs_mobile) do
      Capybara.reset_sessions!
      capybara_login_as_platform_manager
      order_selectors = ['#billing-summary-order', "#billing-summary-offline-#{order.offline_payments.first.id}"]
      surfaces = { "/#{I18n.default_locale}/billing/orders/#{order.id}" => order_selectors,
                   "/#{I18n.default_locale}/billing/checkout/new?plan_id=#{membership.id}" => ['#billing-summary-checkout'] }
      widths.each do |width|
        surfaces.each do |path, selectors|
          visit path
          at_width(width)
          selectors.each { |selector| expect_fits_viewport(selector.start_with?('#') ? selector : "##{selector}") }
        end
        page.execute_script('document.open(); document.write(arguments[0]); document.close();', notice_html(order))
        at_width(width)
        expect_fits_viewport('#billing-summary-email')
        expect(page.evaluate_script('document.querySelector("#billing-summary-email-registrations").getBoundingClientRect().right'))
          .to be <= width
      end
    end
  end

  it 'fits a phone at 320 and 390 wide, with long names, for Quebec and British Columbia' do
    long = create(:better_together_billing_plan, :unlinked, processor: nil, billing_interval: 'one_time', currency: 'CAD', amount_cents: 99_900,
                                                            name: 'Community-membership-with-extended-support-and-training-2027-2028-edition',
                                                            accepted_payment_methods: %w[cash])
    registrations_for('QC', 'QST', 0.09975, '1234567890TQ0001')
    order = place_order(buyer: manager, payment_method: 'cash', tax_address: { country_iso: 'CA', region_code: 'QC' },
                        line_items: [{ purchasable: long }, { purchasable: book }])
    create_billing_address_for(manager, region: 'QC', settlement_name: 'QC')
    expect_surfaces_fit(order, [320, 390])
  end

  it 'captures a Quebec order: GST and QST, a taxed and a zero-rated line' do
    registrations_for('QC', 'QST', 0.09975, '1234567890TQ0001')
    capture_surfaces('quebec', 'QC')
    capture_checkout('quebec', 'QC')
  end

  it 'captures a British Columbia order: GST and PST' do
    registrations_for('BC', 'PST', 0.07, 'PST-1234-5678')
    capture_surfaces('bc', 'BC')
    capture_checkout('bc', 'BC')
  end
end
# rubocop:enable RSpec/NoExpectationExample
