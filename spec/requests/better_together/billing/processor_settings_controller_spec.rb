# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ProcessorSettingsController do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:steward) { find_or_create_test_user("settings-steward-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:member) { find_or_create_test_user("settings-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:other_platform) { create(:better_together_platform) }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

  def settings_path = better_together.billing_processor_settings_path(locale:)
  def setting_path(name) = better_together.billing_processor_setting_path(name, locale:)
  def edit_path(name) = better_together.edit_billing_processor_setting_path(name, locale:)

  def enable_params(_name = 'cash', **overrides)
    { billing_processor_setting: { enabled: '1', acknowledge: '1', hold_hours: '48', purposes: ['', 'one_time', 'ticket'],
                                   settings: { instructions: 'At the hall, Saturdays' } }.merge(overrides) }
  end

  describe 'who may reach it' do
    it 'sends a visitor to sign in' do
      get settings_path

      expect(response).to have_http_status(:found)
    end

    it 'turns a signed-in non-steward away' do
      sign_in member

      get settings_path

      expect(response).to have_http_status(:found)
      expect(response.body).not_to include('billing-processor-settings-table')
    end

    it 'is a 404 while billing is not switched on for the host' do
      sign_in steward
      allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

      get settings_path

      expect(response).to have_http_status(:not_found)
    end

    it 'is open to a steward before any method is on' do
      sign_in steward

      get settings_path

      expect(response).to have_http_status(:ok)
    end
  end

  context 'when signed in as a steward' do
    before { sign_in steward }

    describe 'GET index' do
      it 'lists every installed method outside a vendor, with its state' do
        host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                         settings: { 'instructions' => 'Hall' })

        get settings_path

        expect(response.body).to include('billing-processor-settings-table', 'billing-processor-setting-cash',
                                         'billing-processor-setting-cheque', 'billing-processor-setting-etransfer',
                                         'billing-processor-edit-etransfer')
        expect_html_content(I18n.t('better_together.billing.processor_settings.status_enabled'))
        expect_html_content(I18n.t('better_together.billing.processor_settings.status_not_set_up'))
      end

      it 'says where a country-limited method works' do
        get settings_path

        expect_html_content('CA')
        expect_html_content('CAD')
      end

      it 'does not list a vendor processor' do
        BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })

        get settings_path

        expect(response.body).not_to include('billing-processor-setting-fake')
      end

      it 'does not show another platform\'s state' do
        other_platform.billing_processor_settings.create!(processor: 'cheque', enabled: true, acknowledge: true,
                                                          settings: { 'payee_name' => 'A', 'address' => 'B' })

        get settings_path

        expect(response.body).not_to include('billing-processor-setting-status-badge bg-success')
      end
    end

    describe 'GET edit' do
      it 'shows the fields the method declares and the drawbacks to accept' do
        get edit_path('cheque')

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('billing-processor-setting-form', 'billing-processor-setting-cheque-payee_name',
                                         'billing-processor-setting-cheque-address', 'billing-processor-disclosure',
                                         'billing-processor-acknowledge', 'billing-processor-enable-cheque', 'billing-processor-grant-on')
      end

      it 'offers a choice of when access starts only for a cheque' do
        get edit_path('cash')

        expect(response.body).not_to include('billing-processor-grant-on')
      end

      it 'states the country and currency limit for e-transfer' do
        get edit_path('etransfer')

        expect_html_content(I18n.t('better_together.billing.processor_settings.disclosure_country', countries: 'CA', currencies: 'CAD'))
      end

      it 'shows when the drawbacks were accepted, instead of asking again' do
        host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                         settings: { 'instructions' => 'Hall' })

        get edit_path('cash')

        expect(response.body).to include('billing-processor-acknowledged')
        expect(response.body).not_to include('id="billing-processor-acknowledge"')
      end

      it 'is a 404 for a method that is not installed or is a vendor processor' do
        BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })

        get edit_path('bitcoin')
        expect(response).to have_http_status(:not_found)

        get edit_path('fake')
        expect(response).to have_http_status(:not_found)
      end

      it 'does not resolve a class from the name' do
        get edit_path('Kernel')

        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'PATCH update' do
      it 'turns a method on, saving what buyers are told, encrypted' do
        expect { patch setting_path('cash'), params: enable_params }
          .to change { host_platform.billing_processor_settings.count }.by(1)

        setting = host_platform.billing_processor_settings.find_by(processor: 'cash')
        expect(response).to redirect_to(settings_path)
        expect(setting).to have_attributes(enabled: true, hold_hours: 48, purposes: %w[one_time ticket])
        expect(setting.settings).to eq({ 'instructions' => 'At the hall, Saturdays' })
        expect(setting).to be_acknowledged
        expect(setting.acknowledged_by).to eq(steward.person)
        expect(BetterTogether::Billing.enabled?(host_platform)).to be(true)
      end

      it 'refuses to turn a method on without accepting the drawbacks' do
        patch setting_path('cash'), params: enable_params(acknowledge: '0')

        expect(response).to have_http_status(:unprocessable_content)
        expect(host_platform.billing_processor_settings.where(enabled: true)).to be_empty
        expect(response.body).to include('billing-processor-setting-errors')
      end

      it 'refuses to turn a method on without the information buyers need' do
        patch setting_path('etransfer'), params: enable_params(settings: { recipient_email: '' })

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'turns a method off again, keeping what was entered' do
        patch setting_path('cash'), params: enable_params
        patch setting_path('cash'), params: enable_params(enabled: '0')

        setting = host_platform.billing_processor_settings.find_by(processor: 'cash')
        expect(setting).to have_attributes(enabled: false)
        expect(setting.settings).to eq({ 'instructions' => 'At the hall, Saturdays' })
        expect(BetterTogether::Billing.enabled?(host_platform)).to be(false)
      end

      it 'ignores fields the method does not declare, and a crafted platform or seller' do
        patch setting_path('cash'), params: enable_params(settings: { instructions: 'Hall', bank_account: '999' },
                                                          platform_id: other_platform.id, seller_type: 'Kernel', processor: 'cheque')

        setting = host_platform.billing_processor_settings.find_by(processor: 'cash')
        expect(setting.settings.keys).to eq(['instructions'])
        expect(other_platform.billing_processor_settings).to be_empty
        expect(setting).to have_attributes(seller_type: nil)
      end

      it 'logs the change without the values' do
        patch setting_path('cash'), params: enable_params(settings: { instructions: 'Secret place 4711' })

        event = host_platform.billing_events.find_by(event_type: 'cash.settings_changed')
        expect(event.payload['changed']).to include('enabled')
        expect(event.payload.to_s).not_to include('4711')
        expect(event.payload['actor_id']).to eq(steward.person.id)
      end

      it 'cannot touch another platform\'s setting' do
        other_platform.billing_processor_settings.create!(processor: 'cash', settings: { 'instructions' => 'Theirs' })

        patch setting_path('cash'), params: enable_params(settings: { instructions: 'Mine' })

        expect(other_platform.billing_processor_settings.find_by(processor: 'cash').settings).to eq({ 'instructions' => 'Theirs' })
      end
    end
  end

  context 'when signed in as a member' do
    before { sign_in member }

    it 'cannot change a setting' do
      patch setting_path('cash'), params: enable_params

      expect(host_platform.billing_processor_settings).to be_empty
    end
  end
end
