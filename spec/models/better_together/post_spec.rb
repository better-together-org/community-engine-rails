# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Post do
  it_behaves_like 'an authorable model'

  it 'has a valid factory' do
    expect(build(:better_together_post)).to be_valid
  end

  it 'validates presence of title and content' do
    post = build(:better_together_post, title: nil, content: nil)
    expect(post).not_to be_valid
    expect(post.errors[:title]).to include("can't be blank")
    expect(post.errors[:content]).to include("can't be blank")
  end

  describe '#to_s' do
    it 'returns the title' do
      post = build(:better_together_post, title: 'Example')
      expect(post.to_s).to eq 'Example'
    end
  end

  describe '.latest_first' do
    it 'orders newer published posts before older published posts' do
      older_post = create(:better_together_post, published_at: 3.days.ago, created_at: 4.days.ago)
      newer_post = create(:better_together_post, published_at: 1.day.ago, created_at: 2.days.ago)

      expect(described_class.latest_first).to eq([newer_post, older_post])
    end

    it 'falls back to created_at when published_at is nil' do
      older_draft = create(:better_together_post, published_at: nil, created_at: 3.days.ago)
      newer_draft = create(:better_together_post, published_at: nil, created_at: 1.day.ago)

      expect(described_class.latest_first).to eq([newer_draft, older_draft])
    end

    it 'remains valid when chained with translation joins' do
      older_post = create(:better_together_post, published_at: 3.days.ago, created_at: 4.days.ago)
      newer_post = create(:better_together_post, published_at: 1.day.ago, created_at: 2.days.ago)

      expect { described_class.i18n.latest_first.load }.not_to raise_error
      expect(described_class.i18n.latest_first.where(id: [older_post.id, newer_post.id]).to_a).to eq([newer_post, older_post])
    end
  end

  describe 'after_create #add_creator_as_author' do
    it 'creates an authorship for the creator_id' do
      creator = create(:better_together_person)
      platform = BetterTogether::Platform.find_by(host: true) || create(:better_together_platform)
      post = build(:better_together_post, platform: platform)
      # Ensure no prebuilt authorships from the factory
      post.authorships.clear
      post.creator_id = creator.id
      post.save!

      expect(post.authors.reload.map(&:id)).to include(creator.id)
    end

    it 'does not add the creator when an explicit robot author was selected' do
      creator = create(:better_together_person)
      platform = BetterTogether::Platform.find_by(host: true) || create(:better_together_platform)
      robot = create(:robot, platform:)
      post = described_class.new(title: 'Robot Post', identifier: 'robot-post', content: 'Body', privacy: 'public',
                                 platform:, creator:)

      post.robot_authors << robot
      post.save!

      expect(post.robot_authors).to contain_exactly(robot)
      expect(post.authors).to be_empty
      expect(post.governed_authors).to contain_exactly(robot)
    end
  end

  describe '#governed_authors' do
    it 'includes robot authors alongside people authors' do
      post = create(:better_together_post)
      person = create(:better_together_person)
      robot = create(:robot, platform: post.platform)

      post.authorships.create!(author: person, position: 1)
      post.authorships.create!(author: robot, position: 2)

      expect(post.governed_authors).to eq([post.authorships.first.author, person, robot].uniq)
      expect(post.robot_authors).to include(robot)
    end
  end

  describe '#resolved_contributors_display_visibility' do
    it 'inherits the platform default for posts' do
      platform = create(:better_together_platform, contributors_display_visibility: 'off')
      post = create(:better_together_post, platform:)

      expect(post.resolved_contributors_display_visibility).to eq('off')
      expect(post).not_to be_contributors_display_visible
    end

    it 'lets the post override the platform default' do
      platform = create(:better_together_platform, contributors_display_visibility: 'off')
      post = create(:better_together_post, platform:, contributors_display_visibility: 'on')

      expect(post.resolved_contributors_display_visibility).to eq('on')
      expect(post).to be_contributors_display_visible
    end
  end

  describe 'federation provenance' do
    it 'assigns Current.platform when available' do
      platform = create(:better_together_platform)
      Current.platform = platform

      post = create(:better_together_post)

      expect(post.platform).to eq(platform)
    ensure
      Current.reset
    end

    it 'distinguishes local and remote mirrored origin' do
      local_platform = create(:better_together_platform)
      remote_platform = create(:better_together_platform)
      post = create(:better_together_post, platform: remote_platform, source_id: 'remote-123')

      expect(post.mirrored?).to be true
      expect(post.remote_to_platform?(local_platform)).to be true
      expect(post.local_to_platform?(remote_platform)).to be true
      expect(post.source_identifier).to eq('remote-123')
    end
  end
end
