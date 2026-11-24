# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Where a billing form goes after it saves', :as_platform_manager do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:settings_path) { better_together.billing_processor_settings_path(locale:) }
  let(:params) do
    { billing_processor_setting: { enabled: '1', acknowledge: '1', hold_hours: '48', purposes: ['', 'one_time'],
                                   settings: { instructions: 'At the hall' } } }
  end

  it 'stays inside the tab frame when the form was sent from one' do
    patch better_together.billing_processor_setting_path('cash', locale:), params:,
                                                                           headers: { 'Turbo-Frame' => 'billing-tab-billing-processor-settings' }

    expect(response).to redirect_to(settings_path)
  end

  it 'goes back to the host billing page with that tab open when sent outside a frame' do
    patch better_together.billing_processor_setting_path('cash', locale:), params: params

    expect(response).to redirect_to(better_together.host_dashboard_billing_path(locale:, anchor: 'billing-pane-billing-processor-settings'))
  end

  it 'asks the page to show the screen that was saved, when it is not the tab\'s first screen', :aggregate_failures do
    edit_path = better_together.edit_billing_agreement_requirement_path(SecureRandom.uuid, locale:)

    get better_together.host_dashboard_billing_path(locale:, billing_path: edit_path)

    expect(response.body).to include(%(id="billing-tab-billing-agreement-requirements"), %(src="#{edit_path}"))
  end

  it 'ignores a screen that belongs to another tab or leaves the site' do
    get better_together.host_dashboard_billing_path(locale:, billing_path: '//evil.example/billing/agreement_requirements/x')

    expect(Nokogiri::HTML(response.body).css('turbo-frame[src]').map { |frame| frame['src'] }.join).not_to include('evil.example')
  end
end
