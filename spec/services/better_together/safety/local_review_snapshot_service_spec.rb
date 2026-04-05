# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Safety::LocalReviewSnapshotService do
  describe '#call' do
    let(:repeat_reportable) { create(:better_together_person) }
    let!(:urgent_report) { create(:report, harm_level: 'urgent', retaliation_risk: true) }
    let!(:repeat_report_a) { create(:report, reportable: repeat_reportable) }
    let!(:repeat_report_b) { create(:report, reportable: repeat_reportable) }
    let!(:resolved_report) { create(:report) }

    before do
      resolved_report.safety_case.update!(status: 'resolved')
      BetterTogether::Safety::Note.create!(
        safety_case: urgent_report.safety_case,
        author: urgent_report.reporter,
        visibility: 'participant_visible',
        body: 'Reporter-visible follow-up'
      )
    end

    it 'summarizes deterministic local review signals from open cases' do
      snapshot = described_class.new.call

      expect(snapshot[:open_cases_count]).to eq(3)
      expect(snapshot[:urgent_open_cases_count]).to eq(1)
      expect(snapshot[:unassigned_open_cases_count]).to eq(3)
      expect(snapshot[:retaliation_risk_open_cases_count]).to eq(1)
      expect(snapshot[:repeated_reportables_count]).to eq(1)
      expect(snapshot[:participant_visible_notes_count]).to eq(1)
      expect(snapshot[:generated_at]).to be_a(Time)
    end
  end
end
