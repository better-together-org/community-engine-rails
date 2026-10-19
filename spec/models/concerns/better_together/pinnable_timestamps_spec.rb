# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PinnableTimestamps do
  let(:original) { Time.zone.parse('2026-09-30 06:30') }
  let(:post) { build(:better_together_post) }

  it 'is part of the post model' do
    expect(BetterTogether::Post.included_modules).to include(described_class)
  end

  it 'keeps updated_at equal to created_at after creating when pinned', :aggregate_failures do
    post.created_at = post.updated_at = original
    post.pin_timestamps_to_creation = true
    post.save!

    expect(post.reload.created_at).to be_within(1.second).of(original)
    expect(post.updated_at).to be_within(1.second).of(original)
  end

  it 'sets updated_at back on a later update when one is pinned', :aggregate_failures do
    post.save!
    post.update!(title: 'Changed', pinned_updated_at: original)

    expect(post.reload.updated_at).to be_within(1.second).of(original)
    expect(post.pinned_updated_at).to be_nil
  end

  it 'leaves updated_at alone when not pinned' do
    post.save!

    expect(post.reload.updated_at).to be_within(1.minute).of(Time.zone.now)
  end
end
