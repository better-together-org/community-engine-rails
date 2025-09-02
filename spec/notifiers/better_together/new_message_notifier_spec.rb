# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  # rubocop:disable Metrics/BlockLength
  RSpec.describe NewMessageNotifier do # rubocop:todo RSpec/MultipleMemoizedHelpers
    let(:recipient) { double('Person') } # rubocop:todo RSpec/VerifiedDoubles
    let(:conversation) { double('Conversation', id: 1, title: 'Chat') } # rubocop:todo RSpec/VerifiedDoubles
    let(:sender) { double('Person', name: 'Alice') } # rubocop:todo RSpec/VerifiedDoubles
    let(:content) { double('Content', to_plain_text: 'hello') } # rubocop:todo RSpec/VerifiedDoubles
    let(:message_class) do
      Class.new do
        attr_reader :conversation, :sender, :content

        def self.name = 'Message'
        def self.has_query_constraints? = false
        def self.composite_primary_key? = false
        def self.primary_key = 'id'
        def self.polymorphic_name = name

        def initialize(conversation:, sender:, content:)
          @conversation = conversation
          @sender = sender
          @content = content
        end

        def _read_attribute(attr)
          # rubocop:disable Style/StringConcatenation
          instance_variable_get('@' + attr.to_s)
          # rubocop:enable Style/StringConcatenation
        end
      end
    end
    let(:message) { message_class.new(conversation:, sender:, content:) }
    let(:notification) { double('Notification', recipient: recipient) } # rubocop:todo RSpec/VerifiedDoubles

    subject(:notifier) { described_class.new(record: message) }

    before do
      stub_const('Message', message_class)
    end

    it 'includes unread notification count in message' do
      unread = double('Unread', count: 2) # rubocop:todo RSpec/VerifiedDoubles
      # rubocop:todo RSpec/VerifiedDoubles
      allow(recipient).to receive(:notifications).and_return(double('Notifications', unread: unread))
      # rubocop:enable RSpec/VerifiedDoubles
      result = notifier.send(:build_message, notification)
      expect(result[:unread_count]).to eq(2)
    end
  end
  # rubocop:enable Metrics/BlockLength
end
