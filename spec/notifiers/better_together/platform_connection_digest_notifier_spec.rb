# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformConnectionDigestNotifier do
  subject(:notifier) do
    described_class.new(
      record: platform,
      params: {
        platform: platform,
        platform_connection_ids: [platform_connection.id],
        connection_count: 3,
        review_url: 'https://example.com/connections'
      }
    )
  end

  let(:platform) { create(:better_together_platform) }
  let(:platform_connection) { create(:better_together_platform_connection) }
  let(:steward) { create(:better_together_person) }
  let(:notification) { instance_double(Noticed::Notification, recipient: steward) }

  describe '#title' do
    it 'includes the connection count' do
      expect(notifier.title).to include('3')
    end

    it 'does not raise NameError from bare recipient call' do
      expect { notifier.title }.not_to raise_error
    end
  end

  describe '#body' do
    it 'includes the connection count' do
      expect(notifier.body).to include('3')
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
end
