# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::QuotasHelper do
  describe '#visible_quotas' do
    let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
    let(:storage) { instance_double(BetterTogether::Quota, quota_type: 'media_storage', effective_limit: 0) }
    let(:tokens) { instance_double(BetterTogether::Quota, quota_type: 'ai_translation_tokens', effective_limit: 50_000) }
    let(:zero_tokens) { instance_double(BetterTogether::Quota, quota_type: 'ai_translation_tokens', effective_limit: 0) }

    before { BetterTogether::Robot.update_all(active: false) } # rubocop:disable Rails/SkipsModelValidations

    it 'drops LLM token quotas when translation is unavailable, even with a limit above zero' do
      allow(BetterTogether).to receive(:translation_available?).with(platform:).and_return(false)

      expect(helper.visible_quotas([storage, tokens], platform)).to eq([storage])
    end

    it 'drops LLM token quotas with a zero effective limit when translation is available' do
      allow(BetterTogether).to receive(:translation_available?).with(platform:).and_return(true)

      expect(helper.visible_quotas([storage, zero_tokens], platform)).to eq([storage])
    end

    it 'keeps LLM token quotas with a limit above zero when translation is available' do
      allow(BetterTogether).to receive(:translation_available?).with(platform:).and_return(true)

      expect(helper.visible_quotas([storage, tokens], platform)).to eq([storage, tokens])
    end

    it 'keeps storage quotas regardless of their limit or the translation gate' do
      allow(BetterTogether).to receive(:translation_available?).and_return(false)

      expect(helper.visible_quotas([storage], platform)).to eq([storage])
    end
  end

  describe '#quota_type_label' do
    it 'uses the generalized LLM wording' do
      expect(helper.quota_type_label('ai_translation_tokens')).to eq('AI LLM usage tokens')
    end
  end
end
