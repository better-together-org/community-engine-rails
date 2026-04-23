# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::C3::SettlementNotifier do
  include ActiveJob::TestHelper

  let(:payer)     { create(:better_together_person) }
  let(:recipient) { create(:better_together_person) }
  let(:offer)     { create(:better_together_joatu_offer,   creator: recipient) }
  let(:request)   { create(:better_together_joatu_request, creator: payer) }
  let(:agreement) { create(:better_together_joatu_agreement, offer:, request:) }
  let(:settlement) do
    BetterTogether::Joatu::Settlement.create!(
      agreement: agreement,
      payer: payer,
      recipient: recipient,
      c3_millitokens: 10_000,
      status: 'pending'
    )
  end

  shared_examples 'a valid notification' do |event|
    subject(:notifier) { described_class.with(settlement: settlement, event_type: event) }

    it 'passes validation' do
      expect(notifier).to be_valid
    end

    it 'has a non-blank title' do
      expect(notifier.title).to be_present
    end

    it 'has a non-blank body that includes Tree Seeds' do
      expect(notifier.body).to include('Tree Seeds')
    end

    it 'body does not include millitokens or raw numeric values' do
      expect(notifier.body).not_to match(/\d{4,}/)
    end

    it 'body does not include DID or UUID identifiers' do
      expect(notifier.body).not_to match(/did:key:/)
      expect(notifier.body).not_to match(/[0-9a-f]{8}-[0-9a-f]{4}/)
    end
  end

  describe 'c3_locked event' do
    it_behaves_like 'a valid notification', :c3_locked

    it 'title mentions reservation' do
      notifier = described_class.with(settlement: settlement, event_type: :c3_locked)
      expect(notifier.title.downcase).to match(/reserved|reservation/)
    end

    it 'body mentions the agreement context' do
      notifier = described_class.with(settlement: settlement, event_type: :c3_locked)
      expect(notifier.body).to include('agreement')
    end
  end

  describe 'c3_settled event' do
    it_behaves_like 'a valid notification', :c3_settled

    it 'title mentions exchange or transfer' do
      notifier = described_class.with(settlement: settlement, event_type: :c3_settled)
      expect(notifier.title.downcase).to match(/exchanged|transferred|settled/)
    end
  end

  describe 'c3_lock_released event' do
    it_behaves_like 'a valid notification', :c3_lock_released

    it 'title mentions release or return' do
      notifier = described_class.with(settlement: settlement, event_type: :c3_lock_released)
      expect(notifier.title.downcase).to match(/released|returned/)
    end
  end

  describe '#deliver_later' do
    it 'enqueues notification for each recipient' do
      notifier = described_class.with(settlement: settlement, event_type: :c3_locked)

      expect do
        perform_enqueued_jobs do
          notifier.deliver_later([payer, recipient])
        end
      end.to change { payer.notifications.count + recipient.notifications.count }.by(2)
    end
  end
end
