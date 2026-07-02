# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Ai::Log::TranslationLoggerJob do
  subject(:job) { described_class.new }

  describe 'queue configuration' do
    it 'uses the default queue' do
      expect(described_class.queue_name).to eq('default')
    end
  end

  describe '#perform' do
    let(:base_params) do
      {
        request_content: 'Translate: Hello',
        response_content: 'Bonjour',
        prompt_tokens: 10,
        completion_tokens: 5,
        start_time: 1.second.ago,
        end_time: Time.current,
        model: 'gpt-4o-mini',
        initiator: nil,
        source_locale: 'en',
        target_locale: 'fr',
        estimated_cost: 0.001
      }
    end

    it 'creates an Ai::Log::Translation record' do
      expect { job.perform(**base_params) }
        .to change(BetterTogether::Ai::Log::Translation, :count).by(1)
    end

    it 'sets tokens_used as the sum of prompt and completion tokens' do
      job.perform(**base_params, prompt_tokens: 8, completion_tokens: 4)
      expect(BetterTogether::Ai::Log::Translation.last.tokens_used).to eq(12)
    end

    it 'sets status to success when response_content is present' do
      job.perform(**base_params)
      expect(BetterTogether::Ai::Log::Translation.last.status).to eq('success')
    end

    it 'sets status to failure when response_content is blank' do
      job.perform(**base_params, response_content: '')
      expect(BetterTogether::Ai::Log::Translation.last.status).to eq('failure')
    end

    it 'stores source and target locales' do
      job.perform(**base_params, source_locale: 'en', target_locale: 'fr')
      log = BetterTogether::Ai::Log::Translation.last
      expect(log.source_locale).to eq('en')
      expect(log.target_locale).to eq('fr')
    end
  end
end
