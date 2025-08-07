# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::BlockFilterable, type: :model do
  let(:person) { create(:better_together_person) }
  let(:blocked_person) { create(:better_together_person) }
  let!(:post_by_blocked) { create(:better_together_post, author: blocked_person) }
  let!(:post_by_other) { create(:better_together_post) }

  before do
    BetterTogether::PersonBlock.create!(blocker: person, blocked: blocked_person)
  end

  it 'filters out posts from blocked people' do
    results = BetterTogether::Post.excluding_blocked_for(person)
    expect(results).to include(post_by_other)
    expect(results).not_to include(post_by_blocked)
  end
end
