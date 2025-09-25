# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Conversation do
  describe '#add_participant_safe' do
    let(:conversation) { create(:better_together_conversation) }
    let(:person) { create(:better_together_person) }

    it 'adds a participant when not present' do # rubocop:todo RSpec/MultipleExpectations
      expect do
        conversation.add_participant_safe(person)
      end.to change { conversation.participants.count }.by(1)
      expect(conversation.participants).to include(person)
    end

    # rubocop:todo RSpec/MultipleExpectations
    it 'retries once on ActiveRecord::StaleObjectError and succeeds' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      # Simulate the association raising once, then succeeding on retry.
      proxy = conversation.participants

      call_count = 0
      allow(proxy).to receive(:<<) do |p|
        call_count += 1
        raise ActiveRecord::StaleObjectError.new(p, :update) if call_count == 1

        # perform the actual append on retry
        ActiveRecord::Associations::CollectionProxy.instance_method(:<<).bind(proxy).call(p)
      end

      expect do
        conversation.add_participant_safe(person)
      end.to change { conversation.participants.count }.by(1)

      expect(call_count).to eq(2)
      expect(conversation.participants).to include(person)
    end
  end
end
