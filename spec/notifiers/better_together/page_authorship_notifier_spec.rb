# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe PageAuthorshipNotifier do
    let(:recipient) { double('Person') } # rubocop:todo RSpec/VerifiedDoubles

    let(:page_class) do
      Class.new do
        attr_reader :id, :title

        def self.name = 'Page'
        def self.has_query_constraints? = false
        def self.composite_primary_key? = false
        def self.primary_key = 'id'
        def self.polymorphic_name = name

        def initialize(id:, title:)
          @id = id
          @title = title
        end

        def _read_attribute(attr)
          instance_variable_get("@#{attr}")
        end

        def url
          "https://example.test/pages/#{id}"
        end
      end
    end

    let(:page) { page_class.new(id: 42, title: 'Example Page') }
    # rubocop:todo RSpec/VerifiedDoubles
    let(:notification) { double('Notification', recipient: recipient, record: page) }
    # rubocop:enable RSpec/VerifiedDoubles

    subject(:notifier) { described_class.new(record: page, params: { action: 'added' }) }

    before do
      stub_const('Page', page_class)
    end

    it 'includes unread notification count in message' do
      unread = double('Unread', count: 3) # rubocop:todo RSpec/VerifiedDoubles
      # rubocop:todo RSpec/VerifiedDoubles
      allow(recipient).to receive(:notifications).and_return(double('Notifications', unread: unread))
      # rubocop:enable RSpec/VerifiedDoubles
      result = notifier.send(:build_message, notification)
      expect(result[:unread_count]).to eq(3)
    end

    it 'includes actor name in title when provided' do
      notifier_with_actor = described_class.new(record: page, params: { action: 'added', actor_name: 'Moderator' })
      expect(notifier_with_actor.title).to include('Moderator')
    end
  end
end
