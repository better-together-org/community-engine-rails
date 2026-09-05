# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformConnectionSubmittedNotifier do
  subject(:notifier) do
    described_class.new(
      record: platform_connection,
      params: { platform_connection: platform_connection }
    )
  end

  let(:platform_connection) { create(:better_together_platform_connection) }
  let(:steward) { create(:better_together_person) }
  let(:notification) { instance_double(Noticed::Notification, recipient: steward) }

  describe '#title' do
    it 'describes a federation connection review' do
      expect(notifier.title).to be_present
    end

    it 'does not raise NameError from bare recipient call' do
      expect { notifier.title }.not_to raise_error
    end
  end

  describe '#body' do
    it 'includes the source platform name' do
      expect(notifier.body).to include(platform_connection.source_platform.name)
    end

    it 'includes the target platform name' do
      expect(notifier.body).to include(platform_connection.target_platform.name)
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

    it 'includes a URL to the platform connection' do
      message = notifier.build_message(notification)

      expect(message[:url]).to include(platform_connection.to_param)
    end
  end
end
