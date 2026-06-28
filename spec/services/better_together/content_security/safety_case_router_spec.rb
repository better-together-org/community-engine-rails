# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::SafetyCaseRouter, type: :service do
  let(:creator) { create(:better_together_person) }
  let(:upload)  { create(:better_together_upload, creator: creator) }
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('malware file'),
      filename: "malware-#{SecureRandom.hex(4)}.txt",
      content_type: 'text/plain'
    )
  end
  let(:item) do
    BetterTogether::ContentSecurity::Item.create!(
      blob: blob,
      attachable: upload,
      attachment_name: 'file',
      source_surface: 'uploads',
      lifecycle_state: 'quarantined',
      aggregate_verdict: 'quarantined'
    )
  end
  let(:scan_event) do
    BetterTogether::ContentSecurity::ScanEvent.create!(
      item: item,
      status: 'completed',
      plane: 'technical',
      scanner_name: 'clamav',
      started_at: Time.current,
      verdict: 'quarantined'
    )
  end
  let(:finding) do
    BetterTogether::ContentSecurity::Finding.create!(
      item: item,
      scan_event: scan_event,
      plane: 'technical',
      finding_type: 'malware_signature',
      rule_id: 'Eicar-Test-Signature',
      severity: 'high',
      confidence: 'high',
      verdict: 'quarantined',
      evidence_summary: 'Malware detected: Eicar-Test-Signature',
      detected_at: Time.current
    )
  end

  describe '.route!' do
    context 'when the attachable is an Upload with a Person creator' do
      it 'creates a Report linked to the upload and creator' do
        expect do
          described_class.route!(item: item, finding: finding)
        end.to change(BetterTogether::Report, :count).by(1)

        report = BetterTogether::Report.find_by(reporter: creator, reportable: upload)
        expect(report).to be_present
        expect(report.category).to eq('malware_detected')
        expect(report.harm_level).to eq('high')
        expect(report.requested_outcome).to eq('content_review')
      end

      it 'automatically creates a Safety::Case via the report after_create callback' do
        described_class.route!(item: item, finding: finding)

        report = BetterTogether::Report.find_by(reporter: creator, reportable: upload)
        expect(report.safety_case).to be_present
      end

      it 'links the safety_case to the item and finding' do
        described_class.route!(item: item, finding: finding)

        safety_case = BetterTogether::Report.find_by(reporter: creator, reportable: upload).safety_case
        expect(item.reload.safety_case).to eq(safety_case)
        expect(finding.reload.safety_case).to eq(safety_case)
      end

      it 'creates an internal note on the safety case with the evidence summary' do
        described_class.route!(item: item, finding: finding)

        safety_case = BetterTogether::Report.find_by(reporter: creator, reportable: upload).safety_case
        note = safety_case.notes.find_by(body: finding.evidence_summary)
        expect(note).to be_present
        expect(note.visibility).to eq('internal_only')
        expect(note.author).to eq(creator)
      end

      it 'does not create a duplicate note when called a second time with the same finding' do
        described_class.route!(item: item, finding: finding)

        expect do
          described_class.route!(item: item, finding: finding)
        end.not_to change(BetterTogether::Safety::Note, :count)
      end

      context 'when the finding is a scan_failure' do
        let(:scan_failure_finding) do
          BetterTogether::ContentSecurity::Finding.create!(
            item: item,
            scan_event: scan_event,
            plane: 'technical',
            finding_type: 'scan_failure',
            severity: 'medium',
            confidence: 'medium',
            verdict: 'review_required',
            evidence_summary: 'Malware scanning failed and the upload is being held for review.',
            detected_at: Time.current
          )
        end

        it 'sets category to scan_failure and harm_level to medium' do
          described_class.route!(item: item, finding: scan_failure_finding)

          report = BetterTogether::Report.find_by(reporter: creator, reportable: upload)
          expect(report.category).to eq('scan_failure')
          expect(report.harm_level).to eq('medium')
        end
      end
    end

    context 'when the attachable is not an Upload' do
      let(:non_upload_item) do
        person = create(:better_together_person)
        BetterTogether::ContentSecurity::Item.create!(
          blob: blob,
          attachable: person,
          attachment_name: 'avatar',
          source_surface: 'profiles',
          lifecycle_state: 'quarantined',
          aggregate_verdict: 'quarantined'
        )
      end
      let(:non_upload_scan_event) do
        BetterTogether::ContentSecurity::ScanEvent.create!(
          item: non_upload_item,
          status: 'completed',
          plane: 'technical',
          scanner_name: 'clamav',
          started_at: Time.current,
          verdict: 'quarantined'
        )
      end
      let(:non_upload_finding) do
        BetterTogether::ContentSecurity::Finding.create!(
          item: non_upload_item,
          scan_event: non_upload_scan_event,
          plane: 'technical',
          finding_type: 'malware_signature',
          rule_id: 'Eicar-Test-Signature',
          severity: 'high',
          confidence: 'high',
          verdict: 'quarantined',
          evidence_summary: 'Malware detected.',
          detected_at: Time.current
        )
      end

      it 'does not create a report' do
        expect do
          described_class.route!(item: non_upload_item, finding: non_upload_finding)
        end.not_to change(BetterTogether::Report, :count)
      end
    end

    context 'when the upload has no creator' do
      let(:upload_without_creator) { create(:better_together_upload) }
      let(:no_creator_item) do
        BetterTogether::ContentSecurity::Item.create!(
          blob: blob,
          attachable: upload_without_creator,
          attachment_name: 'file',
          source_surface: 'uploads',
          lifecycle_state: 'quarantined',
          aggregate_verdict: 'quarantined'
        )
      end
      let(:no_creator_scan_event) do
        BetterTogether::ContentSecurity::ScanEvent.create!(
          item: no_creator_item,
          status: 'completed',
          plane: 'technical',
          scanner_name: 'clamav',
          started_at: Time.current,
          verdict: 'quarantined'
        )
      end
      let(:no_creator_finding) do
        BetterTogether::ContentSecurity::Finding.create!(
          item: no_creator_item,
          scan_event: no_creator_scan_event,
          plane: 'technical',
          finding_type: 'malware_signature',
          rule_id: 'Eicar-Test-Signature',
          severity: 'high',
          confidence: 'high',
          verdict: 'quarantined',
          evidence_summary: 'Malware detected.',
          detected_at: Time.current
        )
      end

      it 'does not create a report when creator is nil' do
        expect do
          described_class.route!(item: no_creator_item, finding: no_creator_finding)
        end.not_to change(BetterTogether::Report, :count)
      end
    end
  end
end
