# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederationVisibilityStatusNotifier do
  subject(:notifier) do
    described_class.new(
      record: post,
      params: {
        federatable: post,
        previous_visibility: 'platform_default',
        current_visibility: 'no_federate'
      }
    )
  end

  let(:post) { create(:better_together_post, federation_visibility: 'no_federate') }
  let(:creator) { post.creator }
  let(:notification) { instance_double(Noticed::Notification, recipient: creator) }

  describe '#title' do
    it 'includes the current visibility' do
      expect(notifier.title).to include('no federate')
    end
  end

  describe '#body' do
    it 'includes the item title and current visibility' do
      expect(notifier.body).to include(post.title)
      expect(notifier.body).to include('no federate')
    end
  end

  describe '#url' do
    it 'resolves a path to the federatable item without raising' do
      expect { notifier.url }.not_to raise_error
      expect(notifier.url).to be_present
    end
  end

  describe '#build_message' do
    it 'returns a hash with title, body, and url' do
      message = notifier.build_message(notification)

      expect(message).to include(:title, :body, :url)
    end
  end
end
