# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::FederatedSeedAttributes, type: :service do
  let(:platform) { create(:better_together_platform, :public) }

  describe '.post_attributes' do
    let(:post) { create(:better_together_post, platform:, privacy: 'public') }

    it 'includes core metadata fields' do
      attrs = described_class.post_attributes(post)
      expect(attrs).to include(:title, :identifier, :privacy, :published_at, :updated_at)
    end

    it 'includes content body by default (standard sync_depth)' do
      attrs = described_class.post_attributes(post)
      expect(attrs).to have_key(:content)
    end

    it 'omits content body when sync_depth is metadata' do
      attrs = described_class.post_attributes(post, sync_depth: 'metadata')
      expect(attrs).not_to have_key(:content)
    end
  end

  describe '.page_attributes' do
    let(:page) { create(:better_together_page, platform:) }

    it 'includes core metadata fields' do
      attrs = described_class.page_attributes(page)
      expect(attrs).to include(:title, :identifier, :privacy, :published_at, :updated_at)
    end

    it 'includes layout and template fields' do
      attrs = described_class.page_attributes(page)
      expect(attrs).to include(:layout, :template, :meta_description, :keywords)
    end

    it 'includes an empty blocks array when sync_depth is full' do
      attrs = described_class.page_attributes(page, sync_depth: 'full')
      expect(attrs[:blocks]).to eq([])
    end

    it 'omits the blocks key for standard sync_depth' do
      attrs = described_class.page_attributes(page, sync_depth: 'standard')
      expect(attrs).not_to have_key(:blocks)
    end
  end

  describe '.event_attributes' do
    let(:event) { create(:better_together_event) }

    it 'includes core event metadata' do
      attrs = described_class.event_attributes(event)
      expect(attrs).to include(:name, :identifier, :privacy, :updated_at)
    end

    it 'includes scheduling fields' do
      attrs = described_class.event_attributes(event)
      expect(attrs).to include(:starts_at, :ends_at, :duration_minutes, :timezone)
    end

    it 'includes description body by default (standard sync_depth)' do
      attrs = described_class.event_attributes(event)
      expect(attrs).to have_key(:description)
    end

    it 'omits description body when sync_depth is metadata' do
      attrs = described_class.event_attributes(event, sync_depth: 'metadata')
      expect(attrs).not_to have_key(:description)
    end
  end
end
