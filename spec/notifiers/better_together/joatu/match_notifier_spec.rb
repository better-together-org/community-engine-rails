# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::MatchNotifier do
  let(:offer_creator)   { create(:user, :confirmed, email: 'offer@example.com').person }
  let(:request_creator) { create(:user, :confirmed, email: 'request@example.com').person }
  let(:offer)   { create(:better_together_joatu_offer, creator: offer_creator) }
  let(:request) { create(:better_together_joatu_request, creator: request_creator) }

  # rubocop:todo RSpec/MultipleExpectations
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
end
