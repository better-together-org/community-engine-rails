# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::BotDefense::Challenge do
  describe '.verify' do
    let(:challenge) { described_class.issue(form_id: :membership_request, user_agent: 'RSpecAgent/1.0') }

    it 'accepts a valid challenge after the minimum delay' do
      travel challenge.min_submit_seconds.seconds do
        result = described_class.verify(
          token: challenge.token,
          form_id: :membership_request,
          trap_values: { challenge.trap_field => '' },
          user_agent: 'RSpecAgent/1.0'
        )

        expect(result.success?).to be(true)
      end
    end

    it 'rejects submissions that arrive too quickly' do
      result = described_class.verify(
        token: challenge.token,
        form_id: :membership_request,
        trap_values: { challenge.trap_field => '' },
        user_agent: 'RSpecAgent/1.0'
      )

      expect(result.success?).to be(false)
      expect(result.error).to eq(:submitted_too_quickly)
    end

    it 'rejects replayed challenges' do
      travel challenge.min_submit_seconds.seconds do
        first_result = described_class.verify(
          token: challenge.token,
          form_id: :membership_request,
          trap_values: { challenge.trap_field => '' },
          user_agent: 'RSpecAgent/1.0'
        )
        replay_result = described_class.verify(
          token: challenge.token,
          form_id: :membership_request,
          trap_values: { challenge.trap_field => '' },
          user_agent: 'RSpecAgent/1.0'
        )

        expect(first_result.success?).to be(true)
        expect(replay_result.success?).to be(false)
        expect(replay_result.error).to eq(:replayed_challenge)
      end
    end

    it 'rejects honeypot submissions' do
      travel challenge.min_submit_seconds.seconds do
        result = described_class.verify(
          token: challenge.token,
          form_id: :membership_request,
          trap_values: { challenge.trap_field => 'filled-by-bot' },
          user_agent: 'RSpecAgent/1.0'
        )

        expect(result.success?).to be(false)
        expect(result.error).to eq(:honeypot_triggered)
      end
    end
  end
end
