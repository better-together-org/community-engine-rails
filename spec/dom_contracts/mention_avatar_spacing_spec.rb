# frozen_string_literal: true

require 'rails_helper'

# A post byline shows each author as a mention: an avatar, a gap, then the name. A robot avatar stays a fixed circle.
RSpec.describe 'Mention avatar spacing DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:robot) { create(:robot, platform: BetterTogether::Platform.find_by(host: true), name: 'Byline Robot') }
  let(:post_record) do
    create(:better_together_post, privacy: 'public').tap do |post|
      post.authorships.destroy_all
      post.authorships.create!(author: manager.person)
      post.authorships.create!(author: robot)
      post.update!(published_at: 1.day.ago)
    end
  end
  let(:page_html) { Nokogiri::HTML(response.body) }

  before { get better_together.post_path(post_record, locale: I18n.default_locale) }

  it 'gives the person avatar a gap before the name' do
    avatar = page_html.at_css("##{ActionView::RecordIdentifier.dom_id(manager.person, :mention)} > div.h-50")

    expect(avatar['class'].split).to include('me-2')
  end

  it 'keeps the robot avatar a circle with a gap before the name', :aggregate_failures do
    avatar = page_html.at_css("##{ActionView::RecordIdentifier.dom_id(robot, :mention)} .robot-avatar")

    expect(avatar['class'].split).to include('rounded-circle', 'flex-shrink-0', 'me-2')
    expect(avatar['class'].split).not_to include('h-50')
  end
end
