# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::WebhookDispatcher do
  include ActiveJob::TestHelper

  include_context 'with clean billing processors'

  let!(:host_platform) { configure_host_platform }
  let(:vendor_event) { { 'id' => 'evt_77', 'type' => 'fake.invoice.paid', 'customer_email' => 'person@example.test' } }

  before { BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new }) }

  it 'logs the event once for the platform and enqueues processing by id, never by payload' do
    expect { described_class.new(:fake).call(vendor_event) }.to have_enqueued_job(BetterTogether::Billing::ProcessBillingEventJob)

    event = BetterTogether::Billing::Event.find_by!(processor: 'fake', event_id: 'evt_77')
    expect(event.platform).to eq(host_platform)
    expect(enqueued_jobs.last[:args]).to eq([event.id])
    expect(enqueued_jobs.last.to_s).not_to include('person@example.test')
  end

  it 'does not enqueue a second run for a duplicate delivery of an event that is already being handled' do
    described_class.new(:fake).call(vendor_event)
    BetterTogether::Billing::Event.find_by!(event_id: 'evt_77').update!(processing_status: 'processed', processed_at: Time.current)

    expect { described_class.new(:fake).call(vendor_event) }.not_to have_enqueued_job(BetterTogether::Billing::ProcessBillingEventJob)
    expect(BetterTogether::Billing::Event.where(event_id: 'evt_77').count).to eq(1)
  end

  it 'enqueues again for a duplicate delivery of an event that is still pending, in case the first enqueue was lost' do
    described_class.new(:fake).call(vendor_event)

    expect { described_class.new(:fake).call(vendor_event) }.to have_enqueued_job(BetterTogether::Billing::ProcessBillingEventJob)
    expect(BetterTogether::Billing::Event.where(event_id: 'evt_77').count).to eq(1)
  end

  it 'recovers when the first attempt logged the event but could not enqueue it' do
    allow(BetterTogether::Billing::ProcessBillingEventJob).to receive(:perform_later).and_raise(Redis::CannotConnectError).once
    expect { described_class.new(:fake).call(vendor_event) }.to raise_error(Redis::CannotConnectError)
    allow(BetterTogether::Billing::ProcessBillingEventJob).to receive(:perform_later).and_call_original

    expect { described_class.new(:fake).call(vendor_event) }.to have_enqueued_job(BetterTogether::Billing::ProcessBillingEventJob)
  end

  it 'keeps the vendor event time for ordering' do
    described_class.new(:fake).call(vendor_event.merge('created' => 1_760_000_000))

    expect(BetterTogether::Billing::Event.find_by!(event_id: 'evt_77').processor_event_created_at).to eq(Time.zone.at(1_760_000_000))
  end

  it 'ignores events for a processor that is not installed' do
    BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)

    expect { described_class.new(:fake).call(vendor_event) }.not_to change(BetterTogether::Billing::Event, :count)
  end

  describe 'attributing an event to a platform' do
    let(:other_platform) { create(:better_together_platform) }

    it 'files an event that names its platform under that platform when it has billing configured' do
      described_class.new(:fake).call(vendor_event.merge('platform_id' => host_platform.id))

      expect(BetterTogether::Billing::Event.find_by!(event_id: 'evt_77').platform).to eq(host_platform)
    end

    it 'refuses an event that names a platform with no billing configuration, and stores nothing' do
      allow(BetterTogether).to receive(:report_error)

      expect { described_class.new(:fake).call(vendor_event.merge('platform_id' => other_platform.id)) }
        .to raise_error(BetterTogether::Billing::UnattributableWebhookError, /evt_77 matches no platform/)

      expect(BetterTogether::Billing::Event.where(event_id: 'evt_77')).to be_empty
      expect(BetterTogether).to have_received(:report_error)
        .with(an_instance_of(BetterTogether::Billing::UnattributableWebhookError), context: { processor: :fake, event_id: 'evt_77' })
    end

    it 'does not put the payload in the error it raises or reports' do
      allow(BetterTogether).to receive(:report_error)

      expect { described_class.new(:fake).call(vendor_event.merge('platform_id' => other_platform.id)) }
        .to(raise_error { |error| expect(error.message).not_to include('person@example.test') })
    end

    it 'refuses an event whose processor account matches no configured platform' do
      allow(BetterTogether).to receive(:report_error)
      allow(BetterTogether::Billing::Configuration).to receive(:context_for).and_wrap_original do |original, platform, processor|
        context = original.call(platform, processor)
        next unless context

        BetterTogether::Billing::ProcessorContext.new(platform: context.platform, processor: context.processor, account_ref: 'acct_known')
      end

      expect { described_class.new(:fake).call(vendor_event.merge('account' => 'acct_stranger')) }
        .to raise_error(BetterTogether::Billing::UnattributableWebhookError)
    end
  end
end
