# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'better_together:billing rake tasks', type: :task do
  include_context 'with clean billing processors'

  before do
    Rake.application&.clear
    Rake.application = Rake::Application.new
    load BetterTogether::Engine.root.join('lib/tasks/better_together/billing.rake')
    Rake::Task.define_task(:environment)
  end

  after { Rake.application&.clear }

  let!(:host_platform) { configure_host_platform }
  let(:event) { { 'id' => 'evt_rake_1', 'type' => 'fake.invoice.paid', 'secret' => 'do-not-print' } }
  let(:row) { Pay::Webhook.create!(processor: 'fake', event_type: 'invoice.paid', event:) }

  it 'lists waiting deliveries by id, processor, type and time, and never prints the event' do
    row
    task = Rake::Task['better_together:billing:pay_webhooks']
    task.reenable

    expect { task.invoke }.to output(/#{row.id}  fake\.invoice\.paid/).to_stdout
    expect { task.reenable.then { task.invoke } }.not_to output(/do-not-print/).to_stdout
  end

  it 'says so when nothing is waiting' do
    task = Rake::Task['better_together:billing:pay_webhooks']

    expect { task.invoke }.to output(/No Pay webhook deliveries are waiting/).to_stdout
  end

  it 'processes one kept delivery again and removes it' do
    allow(BetterTogether).to receive(:report_error)
    BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })
    delegator = Pay::Webhooks::Delegator.new
    allow(Pay::Webhooks).to receive(:delegator).and_return(delegator)
    BetterTogether::Billing::WebhookSubscriptions.instance_variable_set(:@subscribed, nil)
    BetterTogether::Billing::WebhookSubscriptions.subscribe_all!
    task = Rake::Task['better_together:billing:reprocess_pay_webhook']

    expect { task.invoke(row.id) }.to output(/Processed fake\.invoice\.paid/).to_stdout
    expect(Pay::Webhook.exists?(row.id)).to be(false)
    expect(BetterTogether::Billing::Event.where(event_id: 'evt_rake_1').count).to eq(1)
  ensure
    delegator&.unsubscribe('fake.invoice.paid')
  end

  it 'needs an id' do
    task = Rake::Task['better_together:billing:reprocess_pay_webhook']

    expect { task.invoke }.to raise_error(SystemExit).and output(/Give the delivery id/).to_stderr
  end
end
