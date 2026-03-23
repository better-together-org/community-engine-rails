# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Comment do
  describe 'database schema' do
    let(:post) { create(:post) }

    it 'has the expected columns' do
      expect(described_class.column_names).to include(
        'id',
        'commentable_type',
        'commentable_id',
        'creator_id',
        'content',
        'created_at',
        'updated_at',
        'lock_version'
      )
    end

    it 'has a UUID primary key' do
      comment = described_class.create!(
        content: 'Test',
        commentable_type: 'BetterTogether::Post',
        commentable_id: post.id
      )
      expect(comment.id).to be_present
      expect(comment.id).to be_a(String)
    end

    it 'has lock_version for optimistic locking' do
      comment = described_class.create!(
        content: 'Test',
        commentable_type: 'BetterTogether::Post',
        commentable_id: post.id
      )
      expect(comment.lock_version).to eq(0)
    end
  end

  describe 'content field' do
    let(:post) { create(:post) }

    it 'has a default empty string for content' do
      comment = described_class.new
      expect(comment.content).to eq('')
    end

    it 'stores text content' do
      comment = described_class.create!(
        content: 'This is my comment',
        commentable_type: 'BetterTogether::Post',
        commentable_id: post.id
      )
      expect(comment.reload.content).to eq('This is my comment')
    end

    it 'allows content to be updated' do
      comment = described_class.create!(
        content: 'Original',
        commentable_type: 'BetterTogether::Post',
        commentable_id: post.id
      )
      comment.update!(content: 'Updated')
      expect(comment.reload.content).to eq('Updated')
    end
  end

  describe 'polymorphic fields' do
    it 'has commentable_type and commentable_id fields' do
      comment = described_class.new
      expect(comment).to respond_to(:commentable_type)
      expect(comment).to respond_to(:commentable_id)
    end

    it 'can store different commentable types' do
      post = create(:post)
      page = create(:page)

      comment1 = described_class.create!(
        commentable_type: 'BetterTogether::Post',
        commentable_id: post.id,
        content: 'Comment on post'
      )
      comment2 = described_class.create!(
        commentable_type: 'BetterTogether::Page',
        commentable_id: page.id,
        content: 'Comment on page'
      )

      expect(comment1.commentable_type).to eq('BetterTogether::Post')
      expect(comment2.commentable_type).to eq('BetterTogether::Page')
    end
  end

  describe 'creator field' do
    let(:post) { create(:post) }

    it 'has a creator_id field' do
      comment = described_class.new
      expect(comment).to respond_to(:creator_id)
    end

    it 'can store creator_id' do
      person = create(:person)
      comment = described_class.create!(
        creator_id: person.id,
        content: 'Test comment',
        commentable_type: 'BetterTogether::Post',
        commentable_id: post.id
      )
      expect(comment.reload.creator_id).to eq(person.id)
    end
  end

  describe 'timestamps' do
    let(:post) { create(:post) }

    it 'sets created_at on creation' do
      comment = described_class.create!(
        content: 'Test',
        commentable_type: 'BetterTogether::Post',
        commentable_id: post.id
      )
      expect(comment.created_at).to be_present
      expect(comment.created_at).to be_within(1.second).of(Time.current)
    end

    it 'updates updated_at on save' do
      comment = described_class.create!(
        content: 'Test',
        commentable_type: 'BetterTogether::Post',
        commentable_id: post.id
      )
      original_updated_at = comment.updated_at
      sleep 0.01
      comment.update!(content: 'Updated')
      expect(comment.updated_at).to be > original_updated_at
    end
  end
end
