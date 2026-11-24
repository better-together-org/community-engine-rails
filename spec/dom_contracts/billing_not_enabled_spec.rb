# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the page a steward sees while billing is off, and the worker row of the readiness checklist.
RSpec.describe 'Billing not enabled DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:password) { 'SecureTest123!@#' }
  let(:steward) { find_or_create_test_user("off-steward-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  before { sign_in steward }

  it 'exposes the not enabled page with each missing step' do
    allow(BetterTogether::Billing::Configuration).to receive_messages(requested?: false, missing_keys: %w[PAY_BUSINESS_NAME])

    get "/#{locale}/billing/plans"

    expect_ids('billing-not-enabled-page', 'billing-not-enabled-intro', 'billing-not-enabled-steps', 'billing-not-enabled-flag',
               'billing-not-enabled-identity', 'billing-not-enabled-back-link', 'billing-not-enabled-note')
  end

  it 'exposes the worker row of the readiness checklist' do
    get "/#{locale}/billing/agreement_requirements"

    expect_ids('billing-readiness-checklist', 'billing-readiness-worker')
  end
end
