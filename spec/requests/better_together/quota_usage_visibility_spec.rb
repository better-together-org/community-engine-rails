# frozen_string_literal: true

require 'rails_helper'

# The Person settings Usage tab and the Community usage tab must gate the AI LLM tokens
# quota identically: translation available on the platform and an effective limit above 0.
RSpec.describe 'Quota usage tab visibility', :as_platform_manager do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let(:person) { BetterTogether::User.find_by(email: 'manager@example.test').person }
  let(:community) { create(:better_together_community, creator: person, privacy: 'public') }
  let(:translation_available) { true }
  let(:token_limit) { 50_000 }
  let(:token_meter) { 'data-testid="quota-usage-meter-ai_translation_tokens"' }
  let(:storage_meter) { 'data-testid="quota-usage-meter-media_storage"' }

  before do
    allow(BetterTogether).to receive(:translation_available?).and_return(translation_available)
    [person, community].each do |owner|
      BetterTogether::Quota.create!(owner:, quota_type: 'media_storage', limit: 250_000_000, period: 'cumulative')
      BetterTogether::Quota.create!(owner:, quota_type: 'ai_translation_tokens', limit: token_limit,
                                    period: 'monthly')
    end
  end

  shared_examples 'both usage tabs' do |show_tokens|
    it "#{show_tokens ? 'shows' : 'hides'} the LLM tokens meter on the person settings Usage tab" do
      get better_together.settings_usage_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(storage_meter)
      expect(response.body.include?(token_meter)).to eq(show_tokens)
    end

    it "#{show_tokens ? 'shows' : 'hides'} the LLM tokens meter on the community usage tab" do
      get better_together.community_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(storage_meter)
      expect(response.body.include?(token_meter)).to eq(show_tokens)
    end
  end

  context 'when translation is unavailable on the platform' do
    let(:translation_available) { false }

    it_behaves_like 'both usage tabs', false
  end

  context 'when translation is available but the limit is zero' do
    let(:token_limit) { 0 }

    it_behaves_like 'both usage tabs', false
  end

  context 'when translation is available and the limit is above zero' do
    it_behaves_like 'both usage tabs', true
  end

  context 'when a zero limit is raised by an active grant' do
    let(:token_limit) { 0 }

    before do
      [person, community].each do |owner|
        create(:better_together_quota_grant, owner:, quota_type: 'ai_translation_tokens', limit: 1_000)
      end
    end

    it_behaves_like 'both usage tabs', true
  end

  context 'when the person has no LLM tokens quota row yet' do
    before { BetterTogether::Quota.where(owner: person, quota_type: 'ai_translation_tokens').delete_all }

    it 'shows no LLM tokens meter on the settings Usage tab until usage creates the row' do
      get better_together.settings_usage_path(locale:)

      expect(response.body).to include(storage_meter)
      expect(response.body).not_to include(token_meter)
    end
  end
end
