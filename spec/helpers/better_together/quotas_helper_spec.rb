# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::QuotasHelper do
  describe '#visible_quotas' do
    let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
    let(:storage) { instance_double(BetterTogether::Quota, quota_type: 'media_storage') }
    let(:tokens) { instance_double(BetterTogether::Quota, quota_type: 'ai_translation_tokens') }

    before { BetterTogether::Robot.update_all(active: false) } # rubocop:disable Rails/SkipsModelValidations

    it 'drops LLM token quotas when no AI provider is configured' do
      allow(RubyLLM.config).to receive(:openai_api_key).and_return(nil)

      expect(helper.visible_quotas([storage, tokens], platform)).to eq([storage])
    end

    it 'keeps them when an OpenAI token is configured' do
      allow(RubyLLM.config).to receive(:openai_api_key).and_return('sk-test')

      expect(helper.visible_quotas([storage, tokens], platform)).to eq([storage, tokens])
    end
  end

  describe '#quota_type_label' do
    it 'uses the generalized LLM wording' do
      expect(helper.quota_type_label('ai_translation_tokens')).to eq('AI LLM usage tokens')
    end
  end
end
