# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Report do
  it 'requires a reason' do # rubocop:todo RSpec/MultipleExpectations
    report = described_class.new
    expect(report).not_to be_valid
    expect(report.errors[:reason]).to include("can't be blank")
  end

  it 'allows a person to report another person' do
    reporter = create(:better_together_person)
    reported = create(:better_together_person)
    report = described_class.create(reporter:, reportable: reported, reason: 'spam')
    expect(report).to be_persisted
  end
end
