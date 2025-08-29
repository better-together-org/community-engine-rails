# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe EventReminderNotifier do
    let(:recipient) { double('Person') } # rubocop:todo RSpec/VerifiedDoubles

    let(:event_class) do
      Class.new do
        attr_reader :id, :name, :starts_at

        def self.name = 'Event'
        def self.has_query_constraints? = false
        def self.composite_primary_key? = false
        def self.primary_key = 'id'
        def self.polymorphic_name = name

        def initialize(id:, name:, starts_at:)
          @id = id
          @name = name
          @starts_at = starts_at
        end

        def _read_attribute(attr)
          instance_variable_get("@#{attr}")
        end

        def present?
          true
        end

        def url
          "https://example.test/events/#{id}"
        end
      end
    end

    let(:event) { event_class.new(id: 42, name: 'Example Event', starts_at: 1.week.from_now) }
    # rubocop:todo RSpec/VerifiedDoubles
    let(:notification) { double('Notification', recipient: recipient, record: event) }
    # rubocop:enable RSpec/VerifiedDoubles

    subject(:notifier) { described_class.new(record: event, params: { reminder_type: '24_hours' }) }

    before do
      stub_const('Event', event_class)
    end

    it 'includes unread notification count in message' do
      unread = double('Unread', count: 3) # rubocop:todo RSpec/VerifiedDoubles
      # rubocop:todo RSpec/VerifiedDoubles
      allow(recipient).to receive(:notifications).and_return(double('Notifications', unread: unread))
      # rubocop:enable RSpec/VerifiedDoubles
      result = notifier.send(:build_message, notification)

      expect(result[:unread_count]).to eq(3)
    end

    it 'includes event name in title' do
      expect(notifier.title).to include('Example Event')
    end

    it 'sets reminder type from params' do
      expect(notifier.reminder_type).to eq('24_hours')
    end

    it 'defaults reminder type when not provided' do
      notifier_without_type = described_class.new(record: event, params: {})
      expect(notifier_without_type.reminder_type).to eq('24_hours')
    end
  end
end
