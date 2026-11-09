# frozen_string_literal: true

require 'rails_helper'

# Our Pay tables are hand-ported from Pay's migrations (we never run `pay:install:migrations`), and our
# encryption and platform scoping rest on how Pay reads and writes its models. These guards fail when a
# Pay upgrade changes either, so the port is done on purpose instead of found in production.
RSpec.describe 'Pay gem compatibility' do # rubocop:disable RSpec/DescribeClass
  let(:pay_root) { Pay::Engine.root }

  # The migrations of the Pay version we ported. A new one means: port it into
  # db/migrate/..._create_better_together_pay_tables.rb (edited in place), then add it here.
  let(:ported_migrations) { %w[1_create_pay_tables.rb 2_add_pay_sti_columns.rb 20250415151129_add_object_to_pay_models.rb] }

  it 'has no Pay migration we have not ported' do
    shipped = Dir[pay_root.join('db/migrate/*.rb')].map { |path| File.basename(path) }.sort

    expect(shipped).to eq(ported_migrations.sort), 'Pay shipped a migration: port it into our Pay tables migration'
  end

  it 'has every column Pay\'s models read and write' do
    expected = {
      Pay::Customer => %w[owner_type owner_id processor processor_id default data object stripe_account deleted_at type],
      Pay::Merchant => %w[owner_type owner_id processor processor_id default data type],
      Pay::PaymentMethod => %w[customer_id processor_id default payment_method_type data stripe_account type],
      Pay::Subscription => %w[customer_id name processor_id processor_plan quantity status current_period_start current_period_end
                              trial_ends_at ends_at metered pause_behavior pause_starts_at pause_resumes_at application_fee_percent
                              metadata data object stripe_account payment_method_id type],
      Pay::Charge => %w[customer_id subscription_id processor_id amount currency application_fee_amount amount_refunded
                        metadata data object stripe_account type],
      Pay::Webhook => %w[processor event_type event]
    }

    expected.each do |model, columns|
      expect(model.column_names).to include(*columns), "#{model} is missing #{(columns - model.column_names).join(', ')}"
    end
  end

  it 'runs no SQL inside the JSON columns we encrypt, which would silently stop matching' do
    sources = Dir[pay_root.join('{app,lib}/**/*.rb')].reject { |path| path.end_with?('lib/pay/adapter.rb') }
    offenders = sources.select { |path| File.read(path).match?(/->>|#>>|\bjsonb\b|data\s*@>|metadata\s*@>|object\s*@>/) }

    expect(offenders).to eq([]), 'Pay now queries inside a JSON column: encrypted columns cannot be searched'
  end

  it 'resolves a processor\'s customer class by name, which our owner wiring and the local processor rely on' do
    expect(Pay::FakeProcessor::Customer.ancestors).to include(Pay::Customer)
    expect(Pay::Customer.inheritance_column).to eq('type')
  end

  it 'gives Pay\'s own subclasses our platform scoping and encryption' do
    [Pay::FakeProcessor::Customer, Pay::FakeProcessor::Subscription, Pay::FakeProcessor::Charge,
     Pay::FakeProcessor::PaymentMethod].each do |model|
      expect(model.ancestors).to include(BetterTogether::Billing::PayExtensions::PlatformScoping,
                                         BetterTogether::Billing::PayExtensions::EncryptedBillingData)
    end
  end

  it 'round-trips a subclass\'s encrypted data through Pay\'s own accessors with no current platform' do
    platform = create(:better_together_platform)
    customer = Pay::FakeProcessor::Customer.create!(owner: create(:better_together_person), platform:, processor: 'fake_processor')
    Current.platform = nil

    charge = customer.charge(1_500, currency: 'cad')

    expect(charge.reload).to have_attributes(platform_id: platform.id, amount: 1_500, brand: 'Fake', last4: 1234)
    raw = Pay::Charge.connection.select_value("SELECT data FROM pay_charges WHERE id = '#{charge.id}'")
    expect(raw).not_to include('Fake')
  end
end
