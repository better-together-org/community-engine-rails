# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Post, type: :model do
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

  describe 'after_create #add_creator_as_author' do
    it 'creates an authorship for the creator_id' do
      creator = create(:better_together_person)
      post = build(:better_together_post)
      # Ensure no prebuilt authorships from the factory
      post.authorships.clear
      post.creator_id = creator.id
      post.save!

      expect(post.authors.reload.map(&:id)).to include(creator.id)
    end
  end
end
