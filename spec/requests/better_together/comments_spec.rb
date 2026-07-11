# frozen_string_literal: true

require 'rails_helper'

# rubocop:todo RSpec/MultipleDescribes
RSpec.describe 'BetterTogether comments' do
  let(:locale) { I18n.default_locale }
  let(:user) { find_or_create_test_user('comments-user@example.test', 'SecureTest123!@#', :user) }
  let(:other_user) { find_or_create_test_user('comments-other-user@example.test', 'SecureTest123!@#', :user) }
  let(:post_author) { find_or_create_test_user('comments-post-author@example.test', 'SecureTest123!@#', :user) }
  let(:target_post) do
    create(:better_together_post, creator: post_author.person, author: post_author.person,
                                  privacy: 'public', published_at: 1.minute.ago)
  end

  describe 'POST /comments' do
    # Unauthenticated access is gated by the standard Devise before_action
    # :authenticate_user! (same mechanism MessagesController/EventsController use)
    # and independently covered at the authorization layer by
    # CommentPolicy#create? ("denies unauthenticated users" in comment_policy_spec.rb).
    # A raw unauthenticated POST can't be exercised at this request-spec layer in the
    # dummy app — even pre-existing routes like /en/posts and /en/reports raise
    # ActionController::RoutingError for an unauthenticated POST here, so this isn't
    # specific to the comments route.

    it 'creates a comment on a whitelisted commentable and notifies the content creator' do
      grant_content_publishing_agreement(user.person)
      sign_in user

      expect do
        post better_together.comments_path(locale:), params: {
          commentable_type: 'BetterTogether::Post',
          commentable_id: target_post.id,
          comment: { content: 'Great post!' }
        }
      end.to change(BetterTogether::Comment, :count).by(1)

      comment = BetterTogether::Comment.last
      expect(comment.content).to eq('Great post!')
      expect(comment.creator).to eq(user.person)
      expect(comment.commentable).to eq(target_post)

      expect(Noticed::Notification.where(
               event_id: BetterTogether::CommentAddedNotifier.where(record: comment).select(:id)
             )).to exist
    end

    it 'does not notify when the commentable creator comments on their own content' do
      grant_content_publishing_agreement(post_author.person)
      sign_in post_author

      expect do
        post better_together.comments_path(locale:), params: {
          commentable_type: 'BetterTogether::Post',
          commentable_id: target_post.id,
          comment: { content: 'Adding more context.' }
        }
      end.to change(BetterTogether::Comment, :count).by(1)

      comment = BetterTogether::Comment.last
      expect(Noticed::Notification.where(
               event_id: BetterTogether::CommentAddedNotifier.where(record: comment).select(:id)
             )).not_to exist
    end

    it 'notifies the post\'s credited author, not just its DB-row creator, when they differ' do
      staff_creator = find_or_create_test_user('comments-staff-creator@example.test', 'SecureTest123!@#', :user)
      credited_author = create(:better_together_person)
      staff_post = create(:better_together_post, creator: staff_creator.person, author: credited_author,
                                                 privacy: 'public', published_at: 1.minute.ago)

      grant_content_publishing_agreement(user.person)
      sign_in user

      post better_together.comments_path(locale:), params: {
        commentable_type: 'BetterTogether::Post',
        commentable_id: staff_post.id,
        comment: { content: 'Great post!' }
      }

      comment = BetterTogether::Comment.last
      event_ids = BetterTogether::CommentAddedNotifier.where(record: comment).select(:id)

      expect(Noticed::Notification.where(recipient: credited_author, event_id: event_ids)).to exist
      expect(Noticed::Notification.where(recipient: staff_creator.person, event_id: event_ids)).not_to exist
    end

    it 'returns not found for a non-whitelisted commentable type' do
      grant_content_publishing_agreement(user.person)
      sign_in user
      page = create(:page)

      expect do
        post better_together.comments_path(locale:), params: {
          commentable_type: 'BetterTogether::Page',
          commentable_id: page.id,
          comment: { content: 'Should not be allowed' }
        }
      end.not_to change(BetterTogether::Comment, :count)

      expect(response).to have_http_status(:not_found)
    end

    it 'does not persist a blank comment and surfaces the error in the turbo_stream response' do
      grant_content_publishing_agreement(user.person)
      sign_in user

      expect do
        post better_together.comments_path(locale:), params: {
          commentable_type: 'BetterTogether::Post',
          commentable_id: target_post.id,
          comment: { content: '   ' }
        }, as: :turbo_stream
      end.not_to change(BetterTogether::Comment, :count)

      expect(response.body).to include('alert-danger')
    end
  end

  describe 'DELETE /comments/:id' do
    it 'allows the comment creator to delete their own comment' do
      sign_in user
      comment = create(:comment, creator: user.person, commentable: target_post)

      expect do
        delete better_together.comment_path(comment, locale:)
      end.to change(BetterTogether::Comment, :count).by(-1)
    end

    it 'denies deletion for a different regular user' do
      sign_in user
      comment = create(:comment, creator: other_user.person, commentable: target_post)

      expect do
        delete better_together.comment_path(comment, locale:)
      end.not_to change(BetterTogether::Comment, :count)

      # Pundit::NotAuthorizedError -> ApplicationController#user_not_authorized redirects back
      # (unlike the not-whitelisted-commentable case, which 404s before authorization runs).
      expect(response).to have_http_status(:redirect)
    end

    it 'allows a platform manager to delete a comment from someone they have personally blocked' do
      manager = find_or_create_test_user('comments-manager@example.test', 'SecureTest123!@#', :platform_manager)
      comment = create(:comment, creator: other_user.person, commentable: target_post)
      create(:person_block, blocker: manager.person, blocked: other_user.person)

      sign_in manager

      # set_comment uses a plain Comment.find, not policy_scope(Comment).find — the
      # policy Scope's excluding_blocked_for(agent) would otherwise 404 this request
      # before authorize ever got a chance to permit it via platform_manager?.
      expect do
        delete better_together.comment_path(comment, locale:)
      end.to change(BetterTogether::Comment, :count).by(-1)
    end
  end
end

RSpec.describe 'BetterTogether::CommentsController self-service publishing agreement gate' do
  let(:locale) { I18n.default_locale }
  let(:commenter) { find_or_create_test_user('comments-gate-user@example.test', 'SecureTest123!@#', :user) }
  let(:post_author) { find_or_create_test_user('comments-gate-post-author@example.test', 'SecureTest123!@#', :user) }
  let(:target_post) do
    create(:better_together_post, creator: post_author.person, author: post_author.person,
                                  privacy: 'public', published_at: 1.minute.ago)
  end

  before { sign_in commenter }

  it 'redirects to the publishing agreement page when the commenter has not accepted it' do
    expect do
      post better_together.comments_path(locale:), params: {
        commentable_type: 'BetterTogether::Post',
        commentable_id: target_post.id,
        comment: { content: 'Great post!' }
      }
    end.not_to change(BetterTogether::Comment, :count)

    expect(response).to redirect_to(%r{/agreements/})
  end

  it 'allows commenting once the agreement is accepted' do
    grant_content_publishing_agreement(commenter.person)

    expect do
      post better_together.comments_path(locale:), params: {
        commentable_type: 'BetterTogether::Post',
        commentable_id: target_post.id,
        comment: { content: 'Great post!' }
      }
    end.to change(BetterTogether::Comment, :count).by(1)
  end
end
# rubocop:enable RSpec/MultipleDescribes
