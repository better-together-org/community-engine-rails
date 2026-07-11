# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSearchFilter do
  describe '#action_text_field (abstract)' do
    it 'raises NotImplementedError when called on the base class' do
      filter = described_class.new(
        resource_class: BetterTogether::Post,
        relation: BetterTogether::Post.all,
        params: { q: 'test' }
      )
      expect { filter.send(:action_text_field) }.to raise_error(NotImplementedError)
    end
  end

  describe 'PostsSearchFilter' do
    let(:platform) { create(:better_together_platform, :public) }
    let!(:public_post) { create(:better_together_post, platform:, privacy: 'public') }
    let!(:private_post) { create(:better_together_post, platform:, privacy: 'private') }

    describe 'privacy filtering' do
      it 'returns all posts when privacy param is blank' do
        result = BetterTogether::PostsSearchFilter.call(relation: BetterTogether::Post.all, params: { privacy: '' })
        expect(result).to include(public_post, private_post)
      end

      it 'filters to public posts only' do
        result = BetterTogether::PostsSearchFilter.call(relation: BetterTogether::Post.all, params: { privacy: 'public' })
        expect(result).to include(public_post)
        expect(result).not_to include(private_post)
      end

      it 'filters to private posts only' do
        result = BetterTogether::PostsSearchFilter.call(relation: BetterTogether::Post.all, params: { privacy: 'private' })
        expect(result).to include(private_post)
        expect(result).not_to include(public_post)
      end

      it 'ignores invalid privacy values and returns all posts' do
        result = BetterTogether::PostsSearchFilter.call(relation: BetterTogether::Post.all, params: { privacy: 'invalid' })
        expect(result).to include(public_post, private_post)
      end
    end

    describe 'ordering' do
      let!(:older_post) do
        create(:better_together_post, platform:, privacy: 'public').tap do |p|
          p.update_column(:created_at, 1.day.ago)
        end
      end

      it 'orders newest-first by default' do
        result = BetterTogether::PostsSearchFilter.call(relation: BetterTogether::Post.all, params: {}).to_a
        newer_idx = result.index(public_post)
        older_idx = result.index(older_post)
        expect(newer_idx).to be < older_idx
      end

      it 'orders oldest-first when order_by=oldest' do
        result = BetterTogether::PostsSearchFilter.call(relation: BetterTogether::Post.all, params: { order_by: 'oldest' }).to_a
        newer_idx = result.index(public_post)
        older_idx = result.index(older_post)
        expect(older_idx).to be < newer_idx
      end
    end

    describe 'category filtering' do
      let(:category) { create(:category) }

      before { public_post.categories << category }

      it 'filters to posts in the given category' do
        result = BetterTogether::PostsSearchFilter.call(relation: BetterTogether::Post.all, params: { category_ids: [category.id] })
        expect(result).to include(public_post)
        expect(result).not_to include(private_post)
      end

      it 'returns all posts when category_ids is empty' do
        result = BetterTogether::PostsSearchFilter.call(relation: BetterTogether::Post.all, params: { category_ids: [] })
        expect(result).to include(public_post, private_post)
      end
    end

    describe 'community filtering' do
      let(:community) { create(:better_together_community) }
      let!(:community_post) { create(:better_together_post, platform:, community:) }

      it 'filters to posts in the given community' do
        result = BetterTogether::PostsSearchFilter.call(
          relation: BetterTogether::Post.all,
          params: { community_ids: [community.id] }
        )
        expect(result).to include(community_post)
        expect(result).not_to include(public_post)
      end

      it 'returns no posts when community_ids is present but empty' do
        result = BetterTogether::PostsSearchFilter.call(relation: BetterTogether::Post.all, params: { community_ids: [] })
        expect(result).to be_empty
      end
    end

    describe 'pagination' do
      it 'returns a Kaminari-paged relation' do
        result = BetterTogether::PostsSearchFilter.call(relation: BetterTogether::Post.all, params: {})
        expect(result).to respond_to(:current_page)
      end
    end
  end
end
