# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::MembershipRequestDeclinedNotifier do
  subject(:notifier) do
    described_class.new(
      record: membership_request,
      params: { membership_request: membership_request }
    )
  end

  let(:community) { create(:better_together_community) }
  let(:membership_request) { create(:membership_request, target: community) }
  let(:requester) { create(:better_together_person) }
  let(:notification) { instance_double(Noticed::Notification, recipient: requester) }

  describe '#title' do
    it 'includes the community name' do
      expect(notifier.title).to include(community.name)
    end

    it 'does not raise NameError from bare recipient call' do
      expect { notifier.title }.not_to raise_error
    end
  end

  describe '#body' do
    it 'includes the community name' do
      expect(notifier.body).to include(community.name)
    end

    it 'does not raise NameError from bare recipient call' do
      expect { notifier.body }.not_to raise_error
    end
  end

  describe '#locale' do
    it 'returns a locale without calling recipient' do
      expect { notifier.locale }.not_to raise_error
      expect(notifier.locale).to eq(I18n.default_locale)
    end
  end

  describe '#build_message' do
    it 'returns a hash with title, body, and url' do
      message = notifier.build_message(notification)

      expect(message).to include(:title, :body, :url)
    end

    it 'does not raise NameError from bare recipient reference' do
      expect { notifier.build_message(notification) }.not_to raise_error
    end

    it 'includes a URL linking to the request' do
      message = notifier.build_message(notification)

      expect(message[:url]).to include(community.to_param)
    end
  end
end
