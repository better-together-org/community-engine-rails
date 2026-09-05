# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::OrchestratorRunner do
  describe '#call' do
    it 'wraps missing command errors as orchestrator errors' do
      runner = described_class.new(command: ['/definitely/missing/orchestrator'])

      expect do
        runner.call('content_item' => { 'text' => 'hello' })
      end.to raise_error(
        BetterTogether::ContentSecurity::OrchestratorRunner::Error,
        /Content safety orchestrator failed:/
      )
    end
  end
end
