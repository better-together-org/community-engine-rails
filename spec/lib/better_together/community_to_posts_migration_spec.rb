# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260604121000_add_community_to_better_together_posts')

RSpec.describe 'Community to posts migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { AddCommunityToBetterTogetherPosts.new }

  it "derives a post's community_id from its platform rather than defaulting to host" do
    federated_platform = create(:better_together_platform, :public, host: false)
    federated_post = create(:better_together_post, platform: federated_platform)
    federated_post.update_column(:community_id, nil)

    migration.send(:backfill_posts_with_host_community)

    expect(federated_post.reload.community_id).to eq(federated_platform.community_id)
  end
end
