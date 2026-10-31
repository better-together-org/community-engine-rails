# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/mention_avatar_spacing_spec.rb'
RSpec.describe 'Documentation screenshots for mention avatar spacing', # rubocop:disable RSpec/SpecFilePathSuffix
               :as_platform_manager,
               :docs_screenshot,
               :js,
               retry: 0,
               type: :feature do
  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:robot) do
    create(:robot, platform: Current.platform || BetterTogether::Platform.find_by(host: true),
                   name: 'BTS Publishing Robot', identifier: 'bts-publishing-robot')
  end
  let(:post_record) do
    create(:better_together_post, title: 'Harbour Update', slug: 'harbour-update', identifier: 'harbour-update').tap do |post|
      post.authorships.destroy_all
      post.authorships.create!(author: manager.person)
      post.authorships.create!(author: robot)
      post.update!(published_at: 1.day.ago, platform: robot.platform)
    end
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  def metadata(flow)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'mention_avatar_spacing', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def visit_post
    capybara_login_as_platform_manager
    visit better_together.post_path(post_record, locale: I18n.default_locale)
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(robot, :mention)}")
  end

  it 'captures the post byline with person and robot mentions' do
    robot_id = ActionView::RecordIdentifier.dom_id(robot, :mention)
    person_id = ActionView::RecordIdentifier.dom_id(manager.person, :mention)
    BetterTogether::CapybaraScreenshotEngine.capture(
      'mention_avatar_spacing', device: :both, metadata: metadata('annotated'),
                                callouts: [
                                  { id: 'person', selector: "##{person_id}", title: 'Person mention',
                                    bullets: ['The avatar sits clear of the name (me-2).'] },
                                  { id: 'robot', selector: "##{robot_id}", title: 'Robot mention',
                                    bullets: ['A round avatar, sized like the person mention, with the same gap.'] }
                                ],
                                narrative: {
                                  title: 'Mentions in a post byline',
                                  audience: %w[community_member developer],
                                  journey_step: 'As a reader, I see who wrote a post.',
                                  callouts: [
                                    { id: 'person', title: 'Person mention', description: 'Avatar, gap, name.' },
                                    { id: 'robot', title: 'Robot mention', description: 'Circle avatar, gap, name.' }
                                  ],
                                  accessibility_notes: 'The robot avatar carries visually hidden "Robot author" text.'
                                }
    ) do
      visit_post
      expect(page).to have_text('BTS Publishing Robot')
    end
  end

  it 'captures the plain byline' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'mention_avatar_spacing_plain', device: :both, metadata: metadata('plain')
    ) do
      visit_post
      expect(page).to have_text('BTS Publishing Robot')
    end
  end
end
