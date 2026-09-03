# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::MatchNotifier do
  let(:offer_creator)   { create(:user, :confirmed, email: 'offer@example.com').person }
  let(:request_creator) { create(:user, :confirmed, email: 'request@example.com').person }
  let(:offer)   { create(:better_together_joatu_offer, creator: offer_creator) }
  let(:request) { create(:better_together_joatu_request, creator: request_creator) }

  it 'does not create duplicate unread notifications for the same pair and recipient' do
    # rubocop:enable RSpec/MultipleExpectations
    notifier = described_class.with(offer:, request:)

    expect { notifier.deliver(offer_creator) }.to change { offer_creator.notifications.count }.by(1)
    # Second delivery should be suppressed by should_notify?
    expect { notifier.deliver(offer_creator) }.not_to(change { offer_creator.notifications.count })

    # Mark as read, allow a subsequent notification
    offer_creator.notifications.unread.update_all(read_at: Time.current)
    expect { notifier.deliver(offer_creator) }.to change { offer_creator.notifications.count }.by(1)
  end

  it 'stamps platform_id from the offer record even with no Current.platform (async delivery)' do # rubocop:disable RSpec/MultipleExpectations
    expect(Current.platform).to be_nil

    notifier = described_class.with(offer:, request:, record: offer)
    notifier.deliver(offer_creator)

    notification = offer_creator.notifications.last
    expect(notification.platform_id).to eq(offer.platform_id)
    expect(notification.platform_id).to be_present
  end
end
