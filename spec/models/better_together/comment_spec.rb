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

    it 'stores a whitelisted commentable type' do
      post = create(:post)

      comment = described_class.create!(
        commentable_type: 'BetterTogether::Post',
        commentable_id: post.id,
        content: 'Comment on post'
      )

      expect(comment.commentable_type).to eq('BetterTogether::Post')
      expect(comment.commentable).to eq(post)
    end

    # A host app opts a model into comments solely by `include BetterTogether::Commentable` —
    # there is no separate gem-owned allow-list to edit. The commentable_type/commentable_id
    # columns are genuinely polymorphic at the DB layer; this validation just requires the
    # target class to actually include the concern, dynamically (see
    # docs/developers/architecture/polymorphic_allowlist_extension_audit.md).
    it 'rejects a commentable type whose class does not include Commentable' do
      page = create(:page)

      comment = described_class.new(
        commentable_type: 'BetterTogether::Page',
        commentable_id: page.id,
        content: 'Comment on page'
      )

      expect(comment).not_to be_valid
      expect(comment.errors[:commentable_type]).to be_present
    end
  end

  describe 'Commentable.included_in_models' do
    it 'includes Post, which explicitly includes the concern' do
      expect(BetterTogether::Commentable.included_in_models).to include(BetterTogether::Post)
    end

    it 'excludes Page, which does not include the concern' do
      expect(BetterTogether::Commentable.included_in_models).not_to include(BetterTogether::Page)
    end
  end

  describe 'associations' do
    let(:post) { create(:post) }

    it 'belongs to a commentable' do
      comment = described_class.create!(content: 'Test', commentable: post)
      expect(comment.commentable).to eq(post)
    end

    it 'belongs to a creator via Creatable' do
      person = create(:person)
      comment = described_class.create!(content: 'Test', commentable: post, creator: person)
      expect(comment.creator).to eq(person)
    end

    it 'has many reports_received for the safety system' do
      comment = create(:comment, commentable: post)
      report = create(:report, reportable: comment, reporter: create(:person))
      expect(comment.reports_received).to include(report)
    end

    it 'does not destroy reports_received (and their safety_case) when the comment is destroyed' do
      comment = create(:comment, commentable: post)
      report = create(:report, reportable: comment, reporter: create(:person))
      safety_case = report.safety_case

      comment.destroy!

      expect(BetterTogether::Report.exists?(report.id)).to be true
      expect(report.reload.reportable).to be_nil
      expect(BetterTogether::Safety::Case.exists?(safety_case.id)).to be true if safety_case
    end
  end

  describe 'validations' do
    it 'requires content' do
      comment = described_class.new(commentable: create(:post), content: '')
      expect(comment).not_to be_valid
      expect(comment.errors[:content]).to be_present
    end

    it 'rejects content over 10,000 characters' do
      comment = described_class.new(commentable: create(:post), content: 'a' * 10_001)
      expect(comment).not_to be_valid
      expect(comment.errors[:content]).to be_present
    end

    it 'accepts content at exactly the 10,000 character limit' do
      comment = described_class.new(commentable: create(:post), content: 'a' * 10_000)
      expect(comment).to be_valid
    end
  end

  describe 'broadcasts' do
    let(:post) { create(:post) }

    # Real-time delivery over the turbo_stream_from(post) subscription is exercised
    # end-to-end by spec/features/better_together/comments_spec.rb; here we only
    # confirm the callbacks are wired to the right target/streamable.
    it 'appends to the commentable stream on create' do
      comment = build(:comment, commentable: post)
      expect(comment).to receive(:broadcast_append_later_to).with(post, target: comment.comments_stream_target)
      comment.save!
    end

    it 'removes from the commentable stream on destroy' do
      comment = create(:comment, commentable: post)
      expect(comment).to receive(:broadcast_remove_to).with(post)
      comment.destroy!
    end

    it 'delegates comments_stream_target to the commentable, the single source of truth for that id' do
      comment = create(:comment, commentable: post)
      expect(comment.comments_stream_target).to eq(post.comments_stream_target)
      expect(comment.comments_stream_target).to eq(ActionView::RecordIdentifier.dom_id(post, :comments))
    end

    it 'exposes a stable anchor_id, the single source of truth for this comment\'s own dom id' do
      comment = create(:comment, commentable: post)
      expect(comment.anchor_id).to eq(ActionView::RecordIdentifier.dom_id(comment))
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
