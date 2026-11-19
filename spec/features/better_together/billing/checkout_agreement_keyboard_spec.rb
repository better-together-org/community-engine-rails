# frozen_string_literal: true

require 'rails_helper'

# A buyer who never touches a mouse can open an agreement, read it, close it, and tick the box it unlocks.
RSpec.describe 'Checkout agreement reader from the keyboard', :js, :no_auth, :skip_host_setup, retry: 0 do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:cash_plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'one_time',
                                                     name: 'Garden plot', currency: 'USD', amount_cents: 2500)
  end
  let(:identifier) { 'one_time_purchase_agreement' }
  let(:link) { "billing-agreement-view-#{identifier}" }
  let(:box) { "billing-agreement-accept-#{identifier}" }

  before do
    Current.platform = host_platform
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    purchase_agreements_for(host_platform)
    create_billing_address_for(find_or_create_test_user('user@example.test').person)
    capybara_login_as_user
    visit "/#{I18n.default_locale}/billing/checkout/new?plan_id=#{cash_plan.id}&payment_method=cash"
  end

  after { Current.platform = nil }

  def focus_element(id) = page.execute_script("document.getElementById('#{id}').focus()")

  def active_id = page.evaluate_script('document.activeElement.id')

  # Focus is handed back when the fade finishes, a moment after the dialog stops matching .show.
  def expect_focus_on(id)
    Timeout.timeout(5) { sleep 0.1 until active_id == id }
  rescue Timeout::Error
    expect(active_id).to eq(id)
  end

  def inside_modal? = page.evaluate_script("!!document.activeElement.closest('#agreementModal')")

  def modal_settled
    Timeout.timeout(10) do
      sleep 0.1 while page.evaluate_script('bootstrap.Modal.getInstance(document.getElementById("agreementModal"))._isTransitioning')
    end
  end

  def open_with(key)
    focus_element(link)
    page.send_keys(key)
    title = BetterTogether::Agreement.find_by!(identifier:).title
    expect(page).to have_css('#agreementModal.show #agreement_modal_frame', text: title, wait: 10)
    modal_settled
  end

  def close_with_escape
    page.send_keys(:escape)
    expect(page).to have_no_css('#agreementModal.show', wait: 10)
  end

  it 'opens from the keyboard with Enter or Space and closes with Escape' do
    %i[enter space].each do |key|
      open_with(key)
      close_with_escape
      modal_settled
      expect(page).to have_no_css('#agreementModal.show')
    end
  end

  it 'puts focus on the readable text, so the arrow and page keys scroll it' do
    open_with(:enter)

    expect(active_id).to eq('agreement-modal-body')
  end

  it 'unlocks the box by reading to the end with the keyboard, then returns focus to the link it opened from' do
    open_with(:enter)
    40.times do
      break if page.has_css?("##{box}[data-better-together-agreement-enabled='true']", visible: :all, wait: 0.3)

      page.send_keys(:page_down)
    end
    expect(page).to have_css("##{box}[data-better-together-agreement-enabled='true']", visible: :all, wait: 5)
    expect(page).to have_css('#agreement-modal-status', text: /read to the end/i, visible: :all)

    close_with_escape
    expect_focus_on(link)

    page.send_keys(:tab)
    expect(active_id).to eq(box)
    page.send_keys(:space)
    expect(page).to have_checked_field(box)
  end

  it 'keeps focus inside the open reader but always leaves a way out' do
    open_with(:enter)

    8.times do
      page.send_keys(:tab)
      expect(inside_modal?).to be(true)
    end
    page.send_keys(%i[shift tab])
    expect(inside_modal?).to be(true)
    close_with_escape
  end

  it 'explains a locked box from the keyboard and puts focus back on the box' do
    focus_element(box)
    page.send_keys(:space)
    expect(page).to have_css('#agreementNoticeModal.show', wait: 10)
    Timeout.timeout(10) do
      sleep 0.1 while page.evaluate_script('bootstrap.Modal.getInstance(document.getElementById("agreementNoticeModal"))._isTransitioning')
    end

    page.send_keys(:escape)
    expect(page).to have_no_css('#agreementNoticeModal.show', wait: 10)
    expect_focus_on(box)
  end

  it 'has no accessibility violations in the open reader' do
    open_with(:enter)

    expect(page).to be_axe_clean.within('#agreementModal').according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa, :wcag22aa)
  end
end
