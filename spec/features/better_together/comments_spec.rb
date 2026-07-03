# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Post comments', :accessibility, :js, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:host_platform) { configure_host_platform }
  let!(:user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let!(:post_author) { create(:better_together_person, name: 'Post Author') }
  let!(:target_post) do
    create(:better_together_post, creator: post_author, author: post_author,
                                  privacy: 'public', published_at: 1.day.ago)
  end

  before { host_platform }

  it 'lets a signed-in member post a comment that appears live, without a full page reload' do
    capybara_login_as_user

    visit better_together.post_path(target_post, locale: I18n.default_locale)

    expect(page).to have_css('.comments-section')
    fill_in t_comment_form_field, with: 'Nicely written post!'
    click_button t_comment_submit

    expect(page).to have_css('.comment', text: 'Nicely written post!', wait: 10)
    expect(page).to have_field(t_comment_form_field, with: '')

    expect(page).to be_axe_clean
      .within('.comments-section')
      .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end

  it 'shows a delete control to a platform steward' do
    comment = create(:comment, creator: post_author, commentable: target_post, content: 'Original comment')

    capybara_login_as_platform_steward
    visit better_together.post_path(target_post, locale: I18n.default_locale)
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(comment)}", wait: 10)
    within("##{ActionView::RecordIdentifier.dom_id(comment)}") do
      # The delete control lives inside a shared/content_actions <details> disclosure,
      # collapsed by default — visible: :all checks presence in the DOM without
      # needing to open the panel first.
      expect(page).to have_css('.fa-trash-can', visible: :all)
    end
  end

  it 'does not show a delete control to an unrelated member' do
    comment = create(:comment, creator: post_author, commentable: target_post, content: 'Original comment')

    capybara_login_as_user
    visit better_together.post_path(target_post, locale: I18n.default_locale)
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(comment)}", wait: 10)
    within("##{ActionView::RecordIdentifier.dom_id(comment)}") do
      expect(page).not_to have_css('.fa-trash-can', visible: :all)
    end
  end

  def t_comment_form_field
    I18n.t('better_together.comments.form.label')
  end

  def t_comment_submit
    I18n.t('better_together.comments.form.submit')
  end
end
