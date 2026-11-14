# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ProcessorSetting do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'

  let!(:host_platform) { configure_host_platform }
  let(:person) { create(:better_together_person) }

  def new_setting(**attrs)
    host_platform.billing_processor_settings.build({ processor: 'cash', settings: { 'instructions' => 'At the hall, Saturdays' } }.merge(attrs))
  end

  def events = host_platform.billing_events.where(event_type: 'cash.settings_changed')

  it_behaves_like 'a platform-bound billing record' do
    def build_record(platform:) = new_setting.tap { |setting| setting.platform = platform }
  end

  it_behaves_like 'encrypts sensitive billing fields' do
    let(:saved_record) { new_setting(settings: { 'instructions' => 'private payee details 4711' }).tap(&:save!) }
    let(:encrypted_fields) { { settings: { 'instructions' => 'private payee details 4711' } } }
  end

  it 'is off by default and holds an unpaid order for three days' do
    setting = new_setting

    expect(setting).to have_attributes(enabled: false, hold_hours: 72)
    expect(setting.purposes).to eq(%w[subscription one_time ticket exchange])
    expect(setting).to be_valid
  end

  describe 'the method' do
    it 'must be an installed method outside a vendor' do
      expect(new_setting(processor: 'bitcoin')).not_to be_valid
      BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })
      remote = new_setting(processor: 'fake')

      expect(remote).not_to be_valid
      expect(remote.errors.details[:processor]).to include(a_hash_including(error: :not_an_offline_method))
    end

    it 'is unique per platform, with a separate row for each seller' do
      new_setting.save!

      expect(new_setting).not_to be_valid
      expect(new_setting(processor: 'cheque')).to be_valid
    end

    it 'cannot change once saved' do
      setting = new_setting.tap(&:save!)

      begin
        setting.update!(processor: 'cheque')
      rescue ActiveRecord::ReadonlyAttributeError
        nil
      end

      expect(setting.reload.processor).to eq('cash')
    end

    it 'backs the uniqueness with the database' do
      new_setting.save!

      expect { new_setting.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'turning it on' do
    it 'needs the seller to accept the drawbacks first' do
      setting = new_setting(enabled: true)

      expect(setting).not_to be_valid
      expect(setting.errors.details[:acknowledge]).to include(a_hash_including(error: :acknowledgement_required))
    end

    it 'records who accepted and when, once' do
      setting = new_setting(enabled: true, acknowledge: true, changed_by: person)
      setting.save!
      accepted_at = setting.acknowledged_at

      setting.update!(acknowledge: true, changed_by: create(:better_together_person))

      expect(setting).to be_acknowledged
      expect(setting.acknowledged_by).to eq(person)
      expect(setting.reload.acknowledged_at).to eq(accepted_at)
    end

    it 'needs the information buyers need to pay' do
      setting = new_setting(enabled: true, acknowledge: true, settings: {})

      expect(setting).not_to be_valid
      expect(setting.errors.details[:settings]).to include(a_hash_including(error: :blank, field: 'instructions'))
    end

    it 'does not check the details of a method that is off, so a draft can be saved' do
      expect(new_setting(enabled: false, settings: {})).to be_valid
    end

    it 'refuses a method that does not exist in the platform\'s country' do
      allow(BetterTogether::Billing::Configuration).to receive(:default_country).and_return('US')
      setting = new_setting(processor: 'etransfer', enabled: true, acknowledge: true, settings: { 'recipient_email' => 'a@example.test' })

      expect(setting).not_to be_valid
      expect(setting.errors.details[:processor]).to include(a_hash_including(error: :country_not_supported, country: 'US'))
    end

    it 'allows a country-limited method when the country is its own, or not known' do
      args = { processor: 'etransfer', enabled: true, acknowledge: true, settings: { 'recipient_email' => 'a@example.test' } }

      allow(BetterTogether::Billing::Configuration).to receive(:default_country).and_return('CA')
      expect(new_setting(**args)).to be_valid
      allow(BetterTogether::Billing::Configuration).to receive(:default_country).and_return(nil)
      expect(new_setting(**args)).to be_valid
    end
  end

  describe 'what is stored' do
    it 'keeps only the fields the method declares, trimmed, dropping blanks' do
      setting = new_setting(settings: { 'instructions' => '  Hall  ', 'recipient_email' => '' })
      setting.valid?

      expect(setting.settings).to eq({ 'instructions' => 'Hall' })
    end

    it 'refuses fields the method does not use' do
      setting = new_setting(settings: { 'instructions' => 'Hall', 'bank_account' => '123' })

      expect(setting).not_to be_valid
      expect(setting.errors.details[:settings]).to include(a_hash_including(error: :unknown_setting, fields: 'bank_account'))
    end

    it 'refuses a value that is far too long' do
      expect(new_setting(settings: { 'instructions' => 'x' * 1_001 })).not_to be_valid
    end

    it 'is encrypted at rest and never in clear text in the table' do
      setting = new_setting(settings: { 'instructions' => 'Meet at 4711 Harbour Road' }).tap(&:save!)

      raw = described_class.connection.select_value("SELECT settings FROM better_together_billing_processor_settings WHERE id = '#{setting.id}'")

      expect(raw).not_to include('4711')
      expect(setting.reload.settings).to eq({ 'instructions' => 'Meet at 4711 Harbour Road' })
    end

    it 'shows buyers the declared fields only' do
      setting = new_setting(processor: 'cheque', settings: { 'payee_name' => 'Harbour Co-op', 'address' => '1 Quay St' })

      expect(setting.instructions).to eq({ 'payee_name' => 'Harbour Co-op', 'address' => '1 Quay St' })
    end
  end

  describe 'options' do
    it 'bounds how long an order is held' do
      expect(new_setting(hold_hours: 0)).not_to be_valid
      expect(new_setting(hold_hours: (24 * 30) + 1)).not_to be_valid
      expect(new_setting(hold_hours: 24)).to be_valid
    end

    it 'accepts only known purposes and at least one' do
      expect(new_setting(purposes: %w[one_time])).to be_valid
      expect(new_setting(purposes: [])).not_to be_valid
      expect(new_setting(purposes: %w[barter])).not_to be_valid
      expect(new_setting(purposes: %w[ticket])).to be_allows(:ticket)
    end

    it 'starts access at the adapter default, and lets a cheque choose' do
      expect(new_setting.grant_on).to eq('confirmed')
      cheque = new_setting(processor: 'cheque', settings: { 'payee_name' => 'A', 'address' => 'B' })
      expect(cheque.grant_on).to eq('cleared')
      expect(new_setting(processor: 'cheque', grant_on: 'received')).to be_valid
      expect(new_setting(processor: 'cheque', grant_on: 'confirmed')).not_to be_valid
      expect(new_setting(grant_on: 'cleared')).not_to be_valid
    end
  end

  describe 'who sells' do
    let(:community) { create(:better_together_community) }

    before { BetterTogether::Billing::Billable.model_names << 'BetterTogether::Community' }

    it 'can be a community, with its own row for the same method' do
      new_setting.save!

      expect(new_setting(seller: community)).to be_valid
      expect(described_class.sold_by_platform.count).to eq(1)
    end

    it 'refuses a seller type that is not allowed' do
      setting = new_setting
      setting.assign_attributes(seller_type: 'Kernel', seller_id: SecureRandom.uuid)

      expect(setting).not_to be_valid
    end
  end

  describe 'the audit trail' do
    it 'logs what changed when a method is turned on, naming fields and never values' do
      new_setting(enabled: true, acknowledge: true, changed_by: person, settings: { 'instructions' => 'Secret place 4711' }).save!

      event = events.last
      expect(event).to have_attributes(outcome_kind: 'settings_changed', processing_status: 'processed')
      expect(event.payload['changed']).to include('enabled', 'settings.instructions')
      expect(event.payload.to_s).not_to include('4711')
      expect(event.payload['actor_id']).to eq(person.id)
      expect(event.subject).to be_a(described_class)
    end

    it 'logs a later change, and nothing when nothing changed' do
      setting = new_setting.tap(&:save!)
      setting.update!(hold_hours: 24)
      before = events.count
      setting.save!

      expect(events.count).to eq(before)
      expect(events.pluck(:payload).map { |payload| payload['changed'] }.flatten).to include('hold_hours')
    end
  end
end
