# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'Safety translation coverage' do
  let(:supported_locales) { %i[en fr es uk] }
  let(:required_keys) do
    %w[
      better_together.reports.new.title
      better_together.reports.new.intro
      better_together.reports.new.category_help
      better_together.reports.new.harm_level_help
      better_together.reports.new.requested_outcome_help
      better_together.reports.new.reason_help
      better_together.reports.new.private_details_help
      better_together.reports.new.preferences_title
      better_together.reports.new.preferences_help
      better_together.reports.new.submit
      better_together.reports.errors.already_reported_by_you
      better_together.reports.index.title
      better_together.reports.show.status
      better_together.safety.shared.any
      better_together.safety.report_categories.boundary_violation
      better_together.safety.harm_levels.urgent
      better_together.safety.requested_outcomes.temporary_protection
      better_together.safety.case_statuses.restorative_in_progress
      better_together.safety.action_types.messaging_restriction
      better_together.safety.note_visibilities.internal_only
      better_together.safety.agreement_statuses.withdrawn
      better_together.safety_cases.attributes.action_type
      better_together.safety_cases.attributes.status
      better_together.safety_cases.show.values_review_placeholder
      better_together.person_block.cannot_block_manager
      better_together.person_blocks.index.title
      better_together.person_blocks.notices.blocked
    ]
  end

  it 'defines required safety keys for each supported locale', :aggregate_failures do
    supported_locales.each do |locale|
      required_keys.each do |key|
        expect(translation_exists?(key, locale)).to be(true), "#{key} missing in #{locale}"
      end
    end
  end

  def translation_exists?(key, locale)
    I18n.t(key, locale:, default: '__missing_translation__') != '__missing_translation__'
  end
end
# rubocop:enable RSpec/DescribeClass
