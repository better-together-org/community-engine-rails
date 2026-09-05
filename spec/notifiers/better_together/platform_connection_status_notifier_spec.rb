# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformConnectionStatusNotifier do
  subject(:notifier) do
    described_class.new(
      record: platform_connection,
      params: {
        platform_connection: platform_connection,
        previous_status: 'pending',
        current_status: 'active'
      }
    )
  end

  let(:platform_connection) { create(:better_together_platform_connection, :active) }
  let(:steward) { create(:better_together_person) }
  let(:notification) { instance_double(Noticed::Notification, recipient: steward) }

  describe '#title' do
    it 'includes the current status' do
      expect(notifier.title).to include('active')
    end

    it 'does not raise NameError from bare recipient call' do
      expect { notifier.title }.not_to raise_error
    end
  end

  describe '#body' do
    it 'includes both platform names' do
      expect(notifier.body).to include(platform_connection.source_platform.name)
      expect(notifier.body).to include(platform_connection.target_platform.name)
    end

    it 'includes the status transition' do
      expect(notifier.body).to include('pending')
      expect(notifier.body).to include('active')
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
