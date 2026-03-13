# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Safety::Case do
  it 'routes urgent reports into the immediate safety lane by default' do
    report = create(
      :report,
      category: 'harassment',
      harm_level: 'urgent',
      requested_outcome: 'temporary_protection'
    )

    expect(report.safety_case.lane).to eq('immediate_safety')
  end

  it 'routes fraud-like reports into the administrative lane by default' do
    report = create(
      :report,
      category: 'fraud',
      harm_level: 'medium',
      requested_outcome: 'content_review'
    )

    expect(report.safety_case.lane).to eq('administrative')
  end
end
