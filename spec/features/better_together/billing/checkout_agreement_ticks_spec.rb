# frozen_string_literal: true

require 'rails_helper'

# A buyer who reads and ticks every agreement, then trips on something else in the form, comes back to
# the same ticks. Only the server can refuse an address, so the page re-renders; the ticks must survive.
RSpec.describe 'Checkout keeps the agreement ticks after an error', :js, :no_auth, :skip_host_setup, retry: 0 do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:cash_plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'one_time',
                                                     name: 'Garden plot', currency: 'USD', amount_cents: 2500)
  end
  let!(:billing_address) { create_billing_address_for(find_or_create_test_user('user@example.test').person) }
  let(:identifiers) { %w[one_time_purchase_agreement offline_payment_terms] }

  before do
    Current.platform = host_platform
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    purchase_agreements_for(host_platform)
    capybara_login_as_user
    visit "/#{I18n.default_locale}/billing/checkout/new?plan_id=#{cash_plan.id}&payment_method=cash"
  end

  after { Current.platform = nil }

  def read_and_tick(identifier) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    box = "#billing-agreement-accept-#{identifier}"
    find("#billing-agreement-view-#{identifier}").click
    title = BetterTogether::Agreement.find_by!(identifier:).title
    expect(page).to have_css('#agreementModal.show #agreement_modal_frame', text: title, wait: 10)
    page.execute_script(<<~JS)
      const body = document.getElementById('agreement_modal_frame').closest('.modal-body');
      body.scrollTop = body.scrollHeight;
      body.dispatchEvent(new Event('scroll', { bubbles: true }));
    JS
    expect(page).to have_css("#{box}[data-better-together-agreement-enabled='true']", visible: :all, wait: 10)
    wait_for_modal_transition
    find('#agreementModal .modal-footer [data-bs-dismiss="modal"]').click
    expect(page).to have_no_css('#agreementModal.show', wait: 10)
    find(box).click
    expect(page).to have_checked_field(box.delete_prefix('#'), visible: :all)
  end

  # Bootstrap ignores a hide while the fade is still running.
  def wait_for_modal_transition
    Timeout.timeout(10) do
      sleep 0.1 while page.evaluate_script('bootstrap.Modal.getInstance(document.getElementById("agreementModal"))._isTransitioning')
    end
  end

  # Only the server refuses this: "new address" chosen with nothing typed in.
  def submit_with_blank_new_address
    page.execute_script("document.getElementById('billing-checkout-address-select').value = 'new'")
    click_button 'billing-checkout-place-btn'
  end

  it 'keeps every ticked box ticked and unlocked, so the buyer can fix the address and place the order' do
    identifiers.each { |identifier| read_and_tick(identifier) }
    submit_with_blank_new_address

    expect(page).to have_css('#billing-checkout-error', wait: 10)
    identifiers.each do |identifier|
      expect(page).to have_checked_field("billing-agreement-accept-#{identifier}")
      expect(page).to have_css("#billing-agreement-accept-#{identifier}[aria-disabled='false']")
    end

    page.execute_script("document.getElementById('billing-checkout-address-select').value = '#{billing_address.id}'")
    click_button 'billing-checkout-place-btn'

    expect(page).to have_current_path(%r{/billing/orders/}, wait: 10)
  end

  # The address selects (SlimSelect listboxes) have their own unnamed-listbox findings; this covers the agreements.
  it 'has no accessibility violations in the agreement section of the re-rendered page' do
    identifiers.each { |identifier| read_and_tick(identifier) }
    submit_with_blank_new_address
    expect(page).to have_css('#billing-checkout-error', wait: 10)

    expect(page).to be_axe_clean.within('#billing-agreement-review').according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa, :wcag22aa)
  end

  it 'still holds a box that was not ticked locked' do
    read_and_tick(identifiers.first)
    page.execute_script("document.getElementById('billing-agreement-accept-#{identifiers.last}').required = false")
    submit_with_blank_new_address

    expect(page).to have_css('#billing-checkout-error', wait: 10)
    expect(page).to have_checked_field("billing-agreement-accept-#{identifiers.first}")
    expect(page).to have_unchecked_field("billing-agreement-accept-#{identifiers.last}")
    expect(page).to have_css("#billing-agreement-accept-#{identifiers.last}[aria-disabled='true']")
  end
end
