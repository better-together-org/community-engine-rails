# frozen_string_literal: true

require 'rails_helper'

# The agreement reader is a dialog opened from a link. Its roles, names and ids are what assistive
# technology and the keyboard flow rely on, so they are locked here.
RSpec.describe 'Billing agreement reader DOM', type: :request do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:member) { find_or_create_test_user("reader-dom-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }
  let(:plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'one_time',
                                                     currency: 'USD', amount_cents: 2500)
  end
  let(:page) { Nokogiri::HTML(response.body) }

  before do
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    purchase_agreements_for(host_platform)
    sign_in member
    get better_together.new_billing_checkout_path(locale:, plan_id: plan.id, payment_method: 'cash')
  end

  it 'makes the scrollable text a focusable, named region' do
    body = page.at_css('#agreementModal #agreement-modal-body')

    expect(body).to be_present
    expect([body['tabindex'], body['role'], body['aria-labelledby']]).to eq(%w[0 region agreementModalLabel])
  end

  it 'announces that the box is unlocked through a polite status region' do
    status = page.at_css('#agreementModal #agreement-modal-status')

    expect(status).to be_present
    expect([status['role'], status['aria-live']]).to eq(%w[status polite])
    expect(page.at_css('#agreement_modal_frame')['data-better_together--agreement-view-complete-message-value']).to be_present
  end

  it 'tells assistive technology that each viewer link opens a dialog, and which agreement it is for', :aggregate_failures do
    page.css('a.agreement-modal-link').each do |link|
      expect(link['aria-haspopup']).to eq('dialog')
      expect(link['data-agreement-title']).to be_present
      described = link['aria-describedby'].to_s.split
      expect(described).not_to be_empty
      expect(described.map { |id| page.at_css("##{id}") }).to all(be_present)
    end
  end
end
