# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ReleasePackageDraftBuilder do
  describe '#call' do
    it 'creates a private draft page and unpublished private post pair' do
      creator = create(:better_together_person)
      robot = create(:better_together_robot)

      result = described_class.new(
        creator: creator,
        title: 'May 1 Launch Package',
        robot_author_ids: [robot.id]
      ).call

      expect(result.page).to be_persisted
      expect(result.post).to be_persisted
      expect(result.page.title).to eq('May 1 Launch Package')
      expect(result.post.title).to eq('May 1 Launch Package')
      expect(result.page.privacy).to eq('private')
      expect(result.post.privacy).to eq('private')
      expect(result.page.published_at).to be_nil
      expect(result.post.published_at).to be_nil
      expect(result.page.authors).to include(creator)
      expect(result.post.authors).to include(creator)
      expect(result.page.robot_authors).to include(robot)
      expect(result.post.robot_authors).to include(robot)
    end
  end
end
