# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::CheckoutSessionSyncBroadcaster do
  subject(:broadcaster) { described_class.new }

  before { allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to) }

  describe '.stream_name' do
    it 'is keyed on the checkout_session_id' do
      expect(described_class.stream_name('cs_test_123')).to eq('checkout_session_cs_test_123')
    end
  end

  describe '.target_dom_id' do
    it 'is keyed on the checkout_session_id' do
      expect(described_class.target_dom_id('cs_test_123')).to eq('checkout-session-sync-cs_test_123')
    end
  end

  describe '#call' do
    it 'broadcasts a success message when the sync result is synced' do
      result = BetterTogether::Billing::StripeCheckoutSessionSync::Result.new(synced: true)

      broadcaster.call(checkout_session_id: 'cs_test_123', result:)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        'checkout_session_cs_test_123',
        hash_including(
          target: 'checkout-session-sync-cs_test_123',
          locals: hash_including(
            messages: [hash_including(variant: :notice, text: a_string_matching(/synchronized successfully/))]
          )
        )
      )
    end

    it 'broadcasts a wrong-beneficiary alert when the sync result is an ownership mismatch' do
      result = BetterTogether::Billing::StripeCheckoutSessionSync::Result.new(synced: false, reason: :beneficiary_mismatch)

      broadcaster.call(checkout_session_id: 'cs_test_123', result:)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        anything,
        hash_including(
          locals: hash_including(
            messages: [hash_including(variant: :alert, text: a_string_matching(/does not belong to this billing page/))]
          )
        )
      )
    end

    it 'broadcasts a pending alert when the sync result is neither synced nor mismatched' do
      result = BetterTogether::Billing::StripeCheckoutSessionSync::Result.new(synced: false, reason: :no_subscription)

      broadcaster.call(checkout_session_id: 'cs_test_123', result:)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        anything,
        hash_including(
          locals: hash_including(
            messages: [hash_including(variant: :alert, text: a_string_matching(/no subscription state could be synchronized/))]
          )
        )
      )
    end

    it 'broadcasts the invalid-session alert when the job caught a Stripe::InvalidRequestError' do
      error = Stripe::InvalidRequestError.new('No such checkout session', 'id')

      broadcaster.call(checkout_session_id: 'cs_bad_id', error:)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        'checkout_session_cs_bad_id',
        hash_including(
          locals: hash_including(
            messages: [hash_including(variant: :alert, text: a_string_matching(/could not be synchronized/))]
          )
        )
      )
    end

    it 'includes a second message for a completed sponsorship contribution' do
      one_time_payment = instance_double(BetterTogether::Billing::OneTimePayment)
      result = BetterTogether::Billing::StripeCheckoutSessionSync::Result.new(synced: true, one_time_payment:)
      beneficiary = instance_double(BetterTogether::Community, name: 'Beneficiary Co-op')
      contribution_result = BetterTogether::Billing::ProcessSponsorshipContributionFromCheckoutSync::Result.new(
        credited: true, already_credited: false, beneficiary:
      )
      allow_any_instance_of( # rubocop:disable RSpec/AnyInstance
        BetterTogether::Billing::ProcessSponsorshipContributionFromCheckoutSync
      ).to receive(:call).with(result).and_return(contribution_result)

      broadcaster.call(checkout_session_id: 'cs_test_123', result:)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        anything,
        hash_including(
          locals: hash_including(
            messages: [
              hash_including(variant: :notice, text: a_string_matching(/synchronized successfully/)),
              hash_including(variant: :notice, text: a_string_matching(/Beneficiary Co-op/))
            ]
          )
        )
      )
    end

    it 'omits the contribution message when the balance was already credited by the webhook leg' do
      one_time_payment = instance_double(BetterTogether::Billing::OneTimePayment)
      result = BetterTogether::Billing::StripeCheckoutSessionSync::Result.new(synced: true, one_time_payment:)
      contribution_result = BetterTogether::Billing::ProcessSponsorshipContributionFromCheckoutSync::Result.new(
        credited: true, already_credited: true
      )
      allow_any_instance_of( # rubocop:disable RSpec/AnyInstance
        BetterTogether::Billing::ProcessSponsorshipContributionFromCheckoutSync
      ).to receive(:call).with(result).and_return(contribution_result)

      broadcaster.call(checkout_session_id: 'cs_test_123', result:)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        anything,
        hash_including(locals: hash_including(messages: [hash_including(variant: :notice)]))
      )
    end
  end
end
