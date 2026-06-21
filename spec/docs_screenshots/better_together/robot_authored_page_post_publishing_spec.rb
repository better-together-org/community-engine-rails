# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for robot-authored page and post publishing',
               :as_platform_manager,
               :docs_screenshot,
               :js,
               retry: 0,
               type: :feature do
  let!(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let!(:robot) do
    create(:robot,
           platform: Current.platform || BetterTogether::Platform.find_by(host: true) || create(:better_together_platform),
           name: 'BTS Publishing Robot',
           identifier: 'bts-publishing-robot')
  end
  let!(:page_record) do
    create(:better_together_page,
           title: 'Robot Authored Page',
           slug: 'robot-authored-page',
           identifier: 'robot-authored-page',
           protected: false,
           published_at: 1.day.ago).tap do |page|
      page.authorships.destroy_all
      page.authorships.create!(author: robot)
      markdown = create(:content_markdown, markdown_source: '## Robot-authored page content')
      page.page_blocks.create!(block: markdown, position: 0)
    end
  end
  let!(:post_record) do
    create(:better_together_post,
           title: 'Robot Authored Post',
           slug: 'robot-authored-post',
           identifier: 'robot-authored-post').tap do |post|
      post.authorships.destroy_all
      post.authorships.create!(author: robot)
      post.update!(published_at: 1.day.ago)
    end
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    page_record.update!(platform: robot.platform) if page_record.platform != robot.platform
    post_record.update!(platform: robot.platform) if post_record.platform != robot.platform
  end

  it 'captures the page edit form with robot authorship controls' do
    capture_docs_screenshot('robot_authored_page_form') do
      sign_in_for_docs_capture
      visit better_together.edit_page_path(page_record, locale: I18n.default_locale)

      expect(page).to have_text('Authors')
      expect(page).to have_text('Contributors')
      expect(page).to have_text('BTS Publishing Robot')
    end
  end

  it 'captures the post edit form with robot authorship controls' do
    capture_docs_screenshot('robot_authored_post_form') do
      sign_in_for_docs_capture
      visit better_together.edit_post_path(post_record, locale: I18n.default_locale)

      expect(page).to have_text('Authors')
      expect(page).to have_text('Contributors')
      expect(page).to have_text('BTS Publishing Robot')
    end
  end

  it 'captures the published page with a robot byline' do
    capture_docs_screenshot('robot_authored_page_show') do
      sign_in_for_docs_capture
      visit better_together.page_path(page_record.slug, locale: I18n.default_locale)

      expect(page).to have_text('Robot Authored Page')
      expect(page).to have_text('BTS Publishing Robot')
      expect(page).to have_text('Robot')
    end
  end

  it 'captures the published post with a robot byline' do
    capture_docs_screenshot('robot_authored_post_show') do
      sign_in_for_docs_capture
      visit better_together.post_path(post_record, locale: I18n.default_locale)

      expect(page).to have_text('Robot Authored Post')
      expect(page).to have_text('BTS Publishing Robot')
      expect(page).to have_text('Robot')
    end
  end

  private

  def capture_docs_screenshot(name, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        feature_set: 'robot_authored_page_post_publishing',
        source_spec: self.class.metadata[:file_path]
      },
      &
    )
  end

  def sign_in_for_docs_capture
    capybara_login_as_platform_manager
  end
end
