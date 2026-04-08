# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Report do
  it 'requires structured intake fields' do
    report = described_class.new(
      category: nil,
      harm_level: nil,
      requested_outcome: nil
    )
    expect(report).not_to be_valid
    expect(report.errors[:reason]).to include("can't be blank")
    expect(report.errors[:category]).to include("can't be blank")
    expect(report.errors[:harm_level]).to include("can't be blank")
    expect(report.errors[:requested_outcome]).to include("can't be blank")
  end

  it 'allows a person to report another person' do
    reporter = create(:better_together_person)
    reported = create(:better_together_person)
    report = described_class.create(
      reporter:,
      reportable: reported,
      reason: 'spam',
      category: 'spam_or_scam',
      harm_level: 'medium',
      requested_outcome: 'content_review'
    )
    expect(report).to be_persisted
  end

  it 'allows pages, communities, and uploads as reportable content surfaces' do
    reporter = create(:better_together_person)
    page = create(:better_together_page)
    community = create(:better_together_community)
    upload = create(:better_together_upload, creator: create(:better_together_person))

    upload.file.attach(
      io: StringIO.new('upload evidence'),
      filename: 'evidence.txt',
      content_type: 'text/plain'
    )
    upload.save!

    [page, community, upload].each do |reportable|
      report = described_class.create(
        reporter:,
        reportable:,
        reason: 'Needs moderator review',
        category: 'other',
        harm_level: 'medium',
        requested_outcome: 'content_review'
      )

      expect(report).to be_persisted
    end
  end

  it 'creates a safety case after intake is saved' do
    report = create(
      :report,
      category: 'boundary_violation',
      harm_level: 'low',
      requested_outcome: 'boundary_support'
    )

    expect(report.safety_case).to be_present
    expect(report.safety_case).to be_a(BetterTogether::Safety::Case)
    expect(report.safety_case.category).to eq('boundary_violation')
  end

  it 'prevents duplicate reports from the same reporter on the same target' do
    reporter = create(:better_together_person)
    reportable = create(:better_together_person)
    create(
      :report,
      reporter:,
      reportable:,
      category: 'harassment',
      harm_level: 'medium',
      requested_outcome: 'boundary_support'
    )

    duplicate = build(
      :report,
      reporter:,
      reportable:,
      category: 'harassment',
      harm_level: 'medium',
      requested_outcome: 'boundary_support'
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:reportable_id]).to be_present
  end
end
