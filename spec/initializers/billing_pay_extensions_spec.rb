# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'config/initializers/billing_pay_extensions.rb' do # rubocop:disable RSpec/DescribeClass
  let(:path) { BetterTogether::Engine.root.join('config/initializers/billing_pay_extensions.rb') }
  let(:platform_scoping) { BetterTogether::Billing::PayExtensions::PlatformScoping }
  let(:encrypted_data) { BetterTogether::Billing::PayExtensions::EncryptedBillingData }
  let(:encrypted_event) { BetterTogether::Billing::PayExtensions::EncryptedWebhookEvent }

  it 'extends every Pay model that holds tenant data with platform scoping and encryption' do
    [Pay::Customer, Pay::Merchant, Pay::PaymentMethod, Pay::Subscription, Pay::Charge].each do |model|
      expect(model.ancestors).to include(platform_scoping, encrypted_data)
    end
    expect(Pay::Webhook.ancestors).to include(encrypted_event)
  end

  it 'runs Pay jobs, including webhook delivery, on the billing queue' do
    expected = [ActiveJob::Base.queue_name_prefix.presence, 'billing'].compact.join(ActiveJob::Base.queue_name_delimiter)

    expect(Pay::Webhooks::ProcessJob.new.queue_name).to eq(expected)
    expect(Pay::CustomerSyncJob.new.queue_name).to eq(expected)
  end

  it 'does not retry a webhook that matches no platform, because retrying cannot change the answer' do
    handlers = Pay::Webhooks::ProcessJob.rescue_handlers.map(&:first)

    expect(handlers).to include('BetterTogether::Billing::UnattributableWebhookError')
  end

  it 'is harmless to run again, as happens on every code reload' do
    expect { 2.times { Rails.application.reloader.prepare! } }.not_to raise_error

    expect(Pay::Customer.ancestors.count(platform_scoping)).to eq(1)
    expect(Pay::Customer.encrypted_billing_attributes).to eq(%i[data object])
  end

  it 'contains only include statements, with the behaviour living in namespaced concerns' do
    statements = File.readlines(path).map(&:strip).reject { |line| line.empty? || line.start_with?('#') }
    code = statements - ['Rails.application.config.to_prepare do', 'end']

    expect(code).to all(match(/\A(\[.*\]\.each do \|model\||model\.include\(|Pay::\w+\.include\()/))
    expect(File.read(path)).not_to match(/class_eval|def |prepend/)
  end

  it 'gives Pay an abstract base of our own, so a host needs no top-level ApplicationRecord' do
    expect(Pay.model_parent_class).to eq('BetterTogether::Billing::PayRecord')
    expect(Pay::ApplicationRecord.superclass).to eq(BetterTogether::Billing::PayRecord)
    expect(BetterTogether::Billing::PayRecord).to be_abstract_class
    expect(Pay::Customer.ancestors).not_to include(BetterTogether::Seedable)
  end
end
