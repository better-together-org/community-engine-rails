# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::MembershipRequestDigestNotifier do
  subject(:notifier) do
    described_class.new(
      record: community,
      params: {
        community: community,
        membership_request_ids: [membership_request.id],
        request_count: 2,
        requestor_names: ['Alice Smith', 'Bob Jones'],
        review_url: 'https://example.com/review',
        send_email: true
      }
    )
  end

  let(:community) { create(:better_together_community) }
  let(:membership_request) { create(:membership_request, target: community) }
  let(:reviewer) { create(:better_together_person) }
  let(:notification) { instance_double(Noticed::Notification, recipient: reviewer) }

  describe '#title' do
    it 'includes the community name' do
      expect(notifier.title).to include(community.name)
    end

    it 'does not raise NameError from bare recipient call' do
      expect { notifier.title }.not_to raise_error
    end
  end

  describe '#body' do
    it 'includes the first requestor name' do
      expect(notifier.body).to include('Alice Smith')
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
  end

  describe '#email_params' do
    it 'uses notification.recipient instead of bare recipient' do
      params = notifier.email_params(notification)

      expect(params[:recipient]).to eq(reviewer)
    end

    it 'includes the community' do
      params = notifier.email_params(notification)

      expect(params[:community]).to eq(community)
    end

    it 'includes membership_request_ids' do
      params = notifier.email_params(notification)

      expect(params[:membership_request_ids]).to include(membership_request.id)
    end

    it 'does not raise NameError from bare recipient reference' do
      expect { notifier.email_params(notification) }.not_to raise_error
    end
  end
end
