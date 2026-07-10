# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for comment permission controls',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', host_url: 'http://www.example.com')
    end
  end
  let(:host_community) { host_platform.community }
  let(:community_member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }
  let(:author) { create(:better_together_person, name: 'Harbour Notes Editor') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after do
    Current.platform = nil
  end

  it 'captures an open comment thread with an existing comment and the post form' do
    commenter = find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user)
    grant_content_publishing_agreement(commenter.person)
    post_record = create(
      :better_together_post,
      title: 'Harbour Cleanup Volunteers Needed',
      author:,
      platform: host_platform,
      community: host_community,
      privacy: 'public',
      published_at: 1.day.ago
    )
    create(:comment,
           creator: author,
           commentable: post_record,
           content: 'Thanks for organizing this — count me in for Saturday.')

    result = capture_docs_screenshot(
      'comment_permission_controls_open_thread',
      flow: 'comment_thread_default',
      callouts: [
        {
          selector: "##{ActionView::RecordIdentifier.dom_id(post_record, :comments)}",
          title: 'Comment thread — default (inherit) settings',
          bullets: [
            'Every existing comment renders oldest-first with the author name, timestamp, and body.',
            'No CommentConfig row exists for this post yet — it reads the default "inherit" state, matching pre-PR behavior for every post.'
          ]
        },
        {
          selector: '#new_comment',
          title: 'Open comment form',
          bullets: [
            'Shown because the signed-in viewer has accepted the content publishing agreement and nothing restricts posting on this post.',
            'Submitting appends the new comment in place via Turbo Stream, no full page reload.'
          ]
        }
      ]
    ) do
      capybara_login_as_user
      visit better_together.post_path(post_record, locale:)

      expect(page).to have_text('Harbour Cleanup Volunteers Needed')
      expect(page).to have_text('Thanks for organizing this')
      expect(page).to have_selector('#new_comment')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/comment_permission_controls_open_thread.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/comment_permission_controls_open_thread.png')
  end

  it 'captures the disabled-comments denial state' do
    commenter = find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user)
    grant_content_publishing_agreement(commenter.person)
    post_record = create(
      :better_together_post,
      title: 'Board Meeting Minutes — June',
      author:,
      platform: host_platform,
      community: host_community,
      privacy: 'public',
      published_at: 1.day.ago
    )
    post_record.comment_permission = 'disabled'
    post_record.save!

    result = capture_docs_screenshot(
      'comment_permission_controls_disabled',
      flow: 'comment_thread_disabled',
      callouts: [
        {
          selector: '#comments-disabled',
          title: 'Comments disabled for this post',
          bullets: [
            'The author or a community content manager set comment_permission to "disabled" via the post edit form.',
            'No manager bypass: even a platform manager cannot post here while this is set — only the denial message renders.',
            'Existing comments (if any) and moderation/delete rights are unaffected — only new comments are blocked.'
          ]
        }
      ]
    ) do
      capybara_login_as_user
      visit better_together.post_path(post_record, locale:)

      expect(page).to have_text('Board Meeting Minutes')
      expect(page).to have_selector('#comments-disabled')
      expect(page).not_to have_selector('#new_comment')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/comment_permission_controls_disabled.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/comment_permission_controls_disabled.png')
  end

  it 'captures the community-members-only denial state for a non-member' do
    commenter = find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user)
    grant_content_publishing_agreement(commenter.person)
    other_community = create(:better_together_community, name: 'Neighbours Only Circle', privacy: 'public')
    post_record = create(
      :better_together_post,
      title: 'Members-Only Planning Notes',
      author:,
      platform: host_platform,
      community: other_community,
      privacy: 'public',
      published_at: 1.day.ago
    )
    post_record.comment_permission = 'community'
    post_record.save!

    result = capture_docs_screenshot(
      'comment_permission_controls_community_required',
      flow: 'comment_thread_community_required',
      callouts: [
        {
          selector: '#comments-community-required',
          title: 'Community-members-only denial message',
          bullets: [
            'The viewer can see this post (visibility stayed at the default "inherit") but is not an active member of Neighbours Only Circle.',
            'comment_permission: "community" lets the post stay publicly visible while restricting who is allowed to add new comments.'
          ]
        }
      ]
    ) do
      capybara_login_as_user
      visit better_together.post_path(post_record, locale:)

      expect(page).to have_text('Members-Only Planning Notes')
      expect(page).to have_selector('#comments-community-required')
      expect(page).not_to have_selector('#new_comment')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/comment_permission_controls_community_required.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/comment_permission_controls_community_required.png')
  end

  it 'captures the CommentConfig fields on the post edit form' do
    manager = find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager)
    post_record = create(
      :better_together_post,
      title: 'Draft: Fall Programming Update',
      author: manager.person,
      platform: host_platform,
      community: host_community,
      privacy: 'public'
    )

    result = capture_docs_screenshot(
      'comment_permission_controls_post_edit_fields',
      flow: 'post_edit_comment_config',
      callouts: [
        {
          selector: "##{ActionView::RecordIdentifier.dom_id(post_record)}_comment_permission",
          title: 'Who can comment',
          bullets: [
            'Nested comment_config fieldset added next to the existing privacy field.',
            'Options: inherit (today\'s default — anyone who can view can comment), community members only, or disabled.'
          ]
        },
        {
          selector: "##{ActionView::RecordIdentifier.dom_id(post_record)}_comment_visibility",
          title: 'Who can see the comment thread',
          bullets: [
            'Independent from the posting permission above — a thread can stay visible to everyone while restricting who may add to it.',
            'Options: inherit (visible to anyone who can view the post) or community members only.'
          ]
        }
      ]
    ) do
      capybara_login_as_platform_manager
      visit better_together.edit_post_path(post_record, locale:)

      expect(page).to have_field('post[title_en]', with: 'Draft: Fall Programming Update')
      expect(page).to have_selector("##{ActionView::RecordIdentifier.dom_id(post_record)}_comment_permission")
      expect(page).to have_selector("##{ActionView::RecordIdentifier.dom_id(post_record)}_comment_visibility")

      # The comment_config fieldset sits well below the fold on this long edit form —
      # scroll it into view so its bounding rect falls inside the captured viewport.
      permission_field = find("##{ActionView::RecordIdentifier.dom_id(post_record)}_comment_permission")
      page.execute_script('arguments[0].scrollIntoView({ block: "center", behavior: "instant" });', permission_field.native)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/comment_permission_controls_post_edit_fields.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/comment_permission_controls_post_edit_fields.png')
  end

  private

  def capture_docs_screenshot(name, flow:, callouts: [], &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name,
      device: :both,
      metadata: {
        locale:,
        role: 'user',
        feature_set: 'comment_permission_controls',
        flow:,
        source_spec: self.class.metadata[:file_path]
      },
      callouts:,
      &
    )
  end
end
