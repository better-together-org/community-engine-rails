# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ProcessorOptionsController do
  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:steward) { find_or_create_test_user("lookup-steward-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:member) { find_or_create_test_user("lookup-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync lookups]) }
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

  before do
    BetterTogether::Billing.register_processor(:fake, -> { adapter })
    allow(Rails).to receive(:cache).and_return(memory_cache)
  end

  def lookup(**params) = get(better_together.billing_processor_options_path(locale:), params: { processor: 'fake' }.merge(params))

  def rows = response.parsed_body

  context 'when signed in as a steward' do
    before { sign_in steward }

    it 'returns {value, text} rows only' do
      lookup(kind: 'products')

      expect(response).to have_http_status(:ok)
      expect(rows).to include({ 'value' => 'prod_pro', 'text' => 'Pro (prod_pro)' })
      expect(rows.flat_map(&:keys).uniq).to contain_exactly('value', 'text')
    end

    it 'narrows prices to a product, and filters by what was typed' do
      lookup(kind: 'prices', scope: { product: 'prod_pro' }, search: 'year')

      expect(rows.pluck('value')).to eq(['price_pro_year'])
    end

    it 'gives the adapter the platform context' do
      lookup(kind: 'products')

      call = adapter.calls.find { |name, *| name == :lookup }
      expect(call[1]).to have_attributes(platform: BetterTogether::Platform.find_by(host: true), processor: :fake)
    end

    it 'serves currencies and intervals that core accepts' do
      lookup(kind: 'currencies')

      expect(rows.pluck('value')).to all(satisfy { |code| BetterTogether::Billing::Plan::SUPPORTED_CURRENCY_CODES.include?(code) })
    end

    it 'falls back to core\'s own lists when the processor has no lookups' do
      BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)
      BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync]) })

      lookup(kind: 'intervals', search: 'mon')

      expect(rows.pluck('value')).to eq(['month'])
    end

    it 'refuses a kind the processor does not serve' do
      lookup(kind: 'customers')

      expect(response).to have_http_status(:unprocessable_content)
      expect(adapter.calls).to be_empty
    end

    it 'refuses a processor that is not configured, resolving nothing from the name' do
      get better_together.billing_processor_options_path(locale:), params: { processor: 'Kernel', kind: 'products' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(adapter.calls).to be_empty
    end

    it 'clamps the limit and the search length' do
      lookup(kind: 'products', limit: '5000', search: 'a' * 1000)

      call = adapter.calls.find { |name, *| name == :lookup }
      expect(call[3].length).to eq(described_class::MAX_SEARCH)
      expect(rows.length).to be <= described_class::MAX_LIMIT
    end

    it 'ignores scope keys it does not understand' do
      lookup(kind: 'prices', scope: { product: 'prod_pro', account: 'acct_other' })

      call = adapter.calls.find { |name, *| name == :lookup }
      expect(call[4]).to eq({ 'product' => 'prod_pro' })
    end

    it 'caches results briefly, so typing is not one API call per keystroke' do
      2.times { lookup(kind: 'products') }

      expect(adapter.calls.count { |name, *| name == :lookup }).to eq(1)
    end

    it 'does not share cached results between platforms' do
      lookup(kind: 'products')
      other = create(:better_together_platform)
      key = ['billing-lookup', other.id, 'fake', 'products', {}, '', described_class::DEFAULT_LIMIT]

      expect(memory_cache.exist?(key)).to be(false)
      expect(memory_cache.instance_variable_get(:@data).keys.join).to include(BetterTogether::Platform.find_by(host: true).id)
    end

    it 'answers an empty list and a header when the processor cannot be reached' do
      lookup(kind: 'products', search: 'boom')

      expect(response).to have_http_status(:ok)
      expect(rows).to eq([])
      expect(response.headers[described_class::UNAVAILABLE_HEADER]).to eq('unavailable')
    end

    it 'reports an unexpected error and still answers an empty list, without the cause' do
      allow(adapter).to receive(:lookup).and_raise(NoMethodError, 'secret internals')
      allow(BetterTogether).to receive(:report_error)

      lookup(kind: 'products')

      expect(rows).to eq([])
      expect(response.body).not_to include('secret internals')
      expect(BetterTogether).to have_received(:report_error).with(an_instance_of(NoMethodError), anything)
    end
  end

  context 'when authorization fails' do
    it 'does not swallow the refusal for a member as an empty list' do
      sign_in member

      lookup(kind: 'products')

      expect(response).to have_http_status(:found)
      expect(response.body).not_to include('prod_pro')
      expect(adapter.calls).to be_empty
    end

    it 'sends a visitor to sign in' do
      lookup(kind: 'products')

      expect(response).to have_http_status(:found)
    end

    it 'is a 404 while billing is off' do
      sign_in steward
      allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

      lookup(kind: 'products')

      expect(response).to have_http_status(:not_found)
    end
  end
end
