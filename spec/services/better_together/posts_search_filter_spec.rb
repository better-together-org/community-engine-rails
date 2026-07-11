# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PostsSearchFilter, type: :service do
  let(:platform) { create(:better_together_platform, :public) }
  let(:author_person) { create(:better_together_person) }
  let!(:authored_post) do
    create(:better_together_post, platform:, privacy: 'public').tap do |post|
      BetterTogether::Authorship.create!(
        authorable: post,
        author: author_person,
        platform:,
        role: BetterTogether::Authorship::AUTHOR_ROLE,
        contribution_type: 'content'
      )
    end
  end
  let!(:other_post) { create(:better_together_post, platform:, privacy: 'public') }

  describe 'author filtering' do
    it 'filters to posts authored by the given person ids' do
      result = described_class.call(
        relation: BetterTogether::Post.all,
        params: { author_ids: [author_person.id] }
      )
      expect(result).to include(authored_post)
      expect(result).not_to include(other_post)
    end

    it 'returns all posts when author_ids is blank' do
      result = described_class.call(
        relation: BetterTogether::Post.all,
        params: { author_ids: [] }
      )
      expect(result).to include(authored_post, other_post)
    end
  end

  describe '#action_text_field' do
    it 'uses content as the action text field name' do
      filter = described_class.new(
        resource_class: BetterTogether::Post,
        relation: BetterTogether::Post.all,
        params: {}
      )
      expect(filter.send(:action_text_field)).to eq('content')
    end
  end
end
