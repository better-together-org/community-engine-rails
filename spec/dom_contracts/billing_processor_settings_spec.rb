# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the payment methods screens: asserts the stable identifiers that
# documentation screenshots (spec/docs_screenshots/better_together/billing_processor_settings_spec.rb)
# and downstream tooling target. Runs in normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Billing processor settings DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  it 'exposes the index identifiers, one row and edit link per method' do
    get "/#{locale}/billing/processor_settings"

    expect(response).to have_http_status(:ok)
    expect_ids('billing-processor-settings-page', 'billing-processor-settings-table')
    %w[cash cheque etransfer].each { |name| expect_ids("billing-processor-setting-#{name}", "billing-processor-edit-#{name}") }
    expect(response.body).to include('billing-processor-setting-status-badge')
  end

  it 'exposes the cash form identifiers' do
    get "/#{locale}/billing/processor_settings/cash/edit"

    expect_ids('billing-processor-setting-edit-page', 'billing-processor-setting-form', 'billing-processor-setting-fields',
               'billing-processor-setting-options', 'billing-processor-hold-hours', 'billing-processor-purposes',
               'billing-processor-purpose-one_time', 'billing-processor-disclosure', 'billing-processor-acknowledge',
               'billing-processor-enable-cash', 'billing-processor-setting-actions', 'billing-processor-setting-save-btn',
               'billing-processor-setting-cash-instructions')
  end

  it 'exposes the cheque fields and the choice of when access starts' do
    get "/#{locale}/billing/processor_settings/cheque/edit"

    expect_ids('billing-processor-setting-cheque-payee_name', 'billing-processor-setting-cheque-address', 'billing-processor-grant-on')
  end

  it 'exposes the e-transfer fields' do
    get "/#{locale}/billing/processor_settings/etransfer/edit"

    expect_ids('billing-processor-setting-etransfer-recipient_email', 'billing-processor-setting-etransfer-recipient_phone')
  end

  it 'exposes the validation errors identifier' do
    patch "/#{locale}/billing/processor_settings/cash", params: { billing_processor_setting: { enabled: '1', settings: { instructions: '' } } }

    expect(response).to have_http_status(:unprocessable_content)
    expect_ids('billing-processor-setting-errors')
  end

  it 'exposes the accepted-on note once the drawbacks were accepted' do
    BetterTogether::Platform.find_by(host: true).billing_processor_settings
                            .create!(processor: 'cash', enabled: true, acknowledge: true, settings: { 'instructions' => 'Hall' })

    get "/#{locale}/billing/processor_settings/cash/edit"

    expect_ids('billing-processor-acknowledged')
  end
end
