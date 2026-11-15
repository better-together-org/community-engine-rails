# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PrivacyCeilingValidatable do
  let(:public_platform)  { create(:better_together_platform, privacy: 'public') }
  let(:private_platform) { create(:better_together_platform, privacy: 'private') }
  let(:public_community) { create(:better_together_community, privacy: 'public') }
  let(:private_community) { create(:better_together_community, privacy: 'private') }

  def page_for(platform:, community: nil, privacy: 'public')
    build(:better_together_page, platform:, community:, privacy:)
  end

  describe '.ceiling_for' do
    it 'is nil without a platform or community' do
      expect(described_class.ceiling_for).to be_nil
    end

    it 'is public only when every wrapper is public' do
      expect(described_class.ceiling_for(platform: public_platform, community: public_community)).to eq('public')
    end

    it 'is community when the platform or community is not public' do
      expect(described_class.ceiling_for(platform: private_platform)).to eq('community')
      expect(described_class.ceiling_for(platform: public_platform, community: private_community)).to eq('community')
    end
  end

  describe 'a record with its own primary community' do
    it 'is not capped by that community, which is its identity and not a container', :aggregate_failures do
      person = create(:better_together_person, privacy: 'public')
      person.community.update_columns(privacy: 'private')

      expect(BetterTogether::Person.privacy_ceiling_wrapper_columns).not_to include('community_id')
      expect(person.reload.effective_privacy).to eq('public')
      expect(BetterTogether::Person.within_privacy_ceiling).to include(person)
    end
  end

  describe '#effective_privacy' do
    it 'caps a public record under a private platform at community' do
      page = page_for(platform: private_platform)

      expect(page).to be_valid
      expect(page.effective_privacy).to eq('community')
      expect(page).to be_privacy_capped
    end

    it 'caps a public record in a private community under a public platform' do
      page = page_for(platform: public_platform, community: private_community)

      expect(page.effective_privacy).to eq('community')
    end

    it 'never opens a record up: private stays private' do
      page = page_for(platform: public_platform, community: public_community, privacy: 'private')

      expect(page.effective_privacy).to eq('private')
      expect(page).not_to be_privacy_capped
    end

    it 'keeps public when platform and community are public' do
      page = page_for(platform: public_platform, community: public_community)

      expect(page.effective_privacy).to eq('public')
      expect(page).to be_effective_privacy_public
    end

    it 'follows the platform when it is released' do
      platform = create(:better_together_platform, privacy: 'private')
      page = create(:better_together_page, platform:, community: nil, privacy: 'public')
      expect(page.effective_privacy).to eq('community')

      # A host platform and its primary community change privacy together.
      platform.update_columns(privacy: 'public') # rubocop:disable Rails/SkipsModelValidations
      page.community.update_columns(privacy: 'public') # rubocop:disable Rails/SkipsModelValidations
      expect(page.reload.effective_privacy).to eq('public')
    end

    it 'does not cap federated mirrors' do
      page = page_for(platform: private_platform)
      page.last_synced_at = Time.current

      expect(page.effective_privacy).to eq('public')
    end

    it 'does not cap exempt models such as agreements' do
      agreement = build(:better_together_agreement, privacy: 'public')

      expect(agreement.effective_privacy).to eq('public')
    end
  end

  describe '.within_privacy_ceiling (SQL twin of #effective_privacy)' do
    it 'keeps rows whose platform and community are public and drops capped rows' do
      open_page = create(:better_together_page, platform: public_platform, community: public_community)
      capped_by_platform = create(:better_together_page, platform: private_platform, community: nil)
      capped_by_community = create(:better_together_page, platform: public_platform, community: private_community)

      ids = BetterTogether::Page.within_privacy_ceiling.pluck(:id)

      expect(ids).to include(open_page.id)
      expect(ids).not_to include(capped_by_platform.id, capped_by_community.id)
    end

    it 'agrees with #effective_privacy_public? for every case' do
      pages = [
        create(:better_together_page, platform: public_platform, community: public_community),
        create(:better_together_page, platform: private_platform, community: nil),
        create(:better_together_page, platform: public_platform, community: private_community)
      ]
      sql_ids = BetterTogether::Page.where(id: pages.map(&:id)).within_privacy_ceiling.pluck(:id)

      expect(sql_ids).to match_array(pages.select(&:effective_privacy_public?).map(&:id))
    end

    it 'is a no-op for models that never carry a ceiling' do
      expect(BetterTogether::Platform.within_privacy_ceiling.to_sql).not_to include('platform_id')
    end
  end
end
