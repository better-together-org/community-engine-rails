# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FeedbackRoutingResolver do
  describe '.call' do
    it 'routes safety reports to the platform safety team' do
      page_record = create(:better_together_page, title: 'Routing page')

      result = described_class.call(page_record, action_kind: :report_safety_issue)

      expect(result.route).to eq(:platform_safety_team)
      expect(result.visibility).to eq(:private_to_reporter_and_platform_safety)
      expect(result.reviewer_permission).to eq('manage_platform_safety')
      expect(result.review_target).to eq(page_record.platform)
      expect(result.owner_person).to eq(page_record.creator)
    end

    it 'routes improvement suggestions for community-scoped pages to community stewards' do
      community = create(:better_together_community, name: 'Routing Community')
      page_record = create(:better_together_page, title: 'Community page', community:)

      result = described_class.call(page_record, action_kind: :suggest_improvement)

      expect(result.route).to eq(:community_stewards)
      expect(result.visibility).to eq(:private_to_submitter_and_stewards)
      expect(result.reviewer_permission).to eq('manage_community_content')
      expect(result.review_target).to eq(community)
    end

    it 'routes profile suggestions to profile stewards' do
      person = create(:better_together_person, name: 'Profile Owner')

      result = described_class.call(person, action_kind: :suggest_improvement)

      expect(result.route).to eq(:profile_stewards)
      expect(result.reviewer_permission).to eq('manage_platform')
      expect(result.owner_person).to eq(person)
    end

    it 'uses the parent page community for block stewardship routing' do
      community = create(:better_together_community, name: 'Section Reviewers')
      page_record = create(:better_together_page, title: 'Block page', community:)
      block = create(:better_together_content_rich_text, content_html: '<p>Block</p>')
      create(:better_together_content_page_block, page: page_record, block:)

      result = described_class.call(block, action_kind: :suggest_improvement)

      expect(result.route).to eq(:community_stewards)
      expect(result.review_target).to eq(community)
    end
  end
end
