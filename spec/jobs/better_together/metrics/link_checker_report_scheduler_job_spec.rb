# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::LinkCheckerReportSchedulerJob do
  include ActiveJob::TestHelper

  let(:from_date) { Date.parse('2025-09-01') }
  let(:to_date) { Date.parse('2025-09-01') }

  describe '#perform' do
    context 'when report has broken links and no previous report exists' do
      before do
        fake_report = double(
          id: 1,
          report_file: double(attached?: true),
          no_broken_links?: false,
          broken_links_changed_since?: true
        )

        # Mock the ActiveRecord query chain
        # rubocop:disable RSpec/VerifiedDoubles
        relation = double('ActiveRecord::Relation')
        # rubocop:enable RSpec/VerifiedDoubles
        allow(BetterTogether::Metrics::LinkCheckerReport).to receive_messages(create_and_generate!: fake_report, where: relation)
        allow(relation).to receive_messages(not: relation, order: relation, first: nil)

        allow(BetterTogether::Metrics::ReportMailer).to receive(:link_checker_report)
          .and_return(double(deliver_later: true))
      end

      it 'sends email for first report with broken links' do
        expect(BetterTogether::Metrics::ReportMailer).to receive(:link_checker_report).with(1)
        described_class.perform_now(from_date: from_date, to_date: to_date)
      end
    end

    context 'when report has no broken links' do
      before do
        fake_report = double(
          id: 1,
          report_file: double(attached?: true),
          no_broken_links?: true
        )

        allow(BetterTogether::Metrics::LinkCheckerReport).to receive(:create_and_generate!)
          .and_return(fake_report)
      end

      it 'does not send email' do
        expect(BetterTogether::Metrics::ReportMailer).not_to receive(:link_checker_report)
        described_class.perform_now(from_date: from_date, to_date: to_date)
      end
    end

    context 'when broken links have not changed since previous report' do
      let(:previous_report) do
        double(
          id: 1,
          report_data: { 'invalid_by_host' => { 'example.com' => 2 } }
        )
      end

      let(:current_report) do
        double(
          id: 2,
          report_file: double(attached?: true),
          no_broken_links?: false,
          broken_links_changed_since?: false
        )
      end

      before do
        # Mock the ActiveRecord query chain
        # rubocop:disable RSpec/VerifiedDoubles
        relation = double('ActiveRecord::Relation')
        # rubocop:enable RSpec/VerifiedDoubles
        allow(BetterTogether::Metrics::LinkCheckerReport).to receive_messages(create_and_generate!: current_report, where: relation)
        allow(relation).to receive_messages(not: relation, order: relation, first: previous_report)

        allow(current_report).to receive(:broken_links_changed_since?).with(previous_report).and_return(false)
      end

      it 'does not send email when broken links are unchanged' do
        expect(BetterTogether::Metrics::ReportMailer).not_to receive(:link_checker_report)
        described_class.perform_now(from_date: from_date, to_date: to_date)
      end
    end

    context 'when broken links have changed since previous report' do
      let(:previous_report) do
        double(
          id: 1,
          report_data: { 'invalid_by_host' => { 'example.com' => 2 } }
        )
      end

      let(:current_report) do
        double(
          id: 2,
          report_file: double(attached?: true),
          no_broken_links?: false,
          broken_links_changed_since?: true
        )
      end

      before do
        # Mock the ActiveRecord query chain
        # rubocop:disable RSpec/VerifiedDoubles
        relation = double('ActiveRecord::Relation')
        # rubocop:enable RSpec/VerifiedDoubles
        allow(BetterTogether::Metrics::LinkCheckerReport).to receive_messages(create_and_generate!: current_report, where: relation)
        allow(relation).to receive_messages(not: relation, order: relation, first: previous_report)

        allow(current_report).to receive(:broken_links_changed_since?).with(previous_report).and_return(true)
        allow(BetterTogether::Metrics::ReportMailer).to receive(:link_checker_report)
          .and_return(double(deliver_later: true))
      end

      it 'sends email when broken links have changed' do
        expect(BetterTogether::Metrics::ReportMailer).to receive(:link_checker_report).with(2)
        described_class.perform_now(from_date: from_date, to_date: to_date)
      end
    end

    context 'when report file is not attached' do
      before do
        fake_report = double(
          id: 1,
          report_file: double(attached?: false)
        )

        allow(BetterTogether::Metrics::LinkCheckerReport).to receive(:create_and_generate!)
          .and_return(fake_report)
      end

      it 'does not send email' do
        expect(BetterTogether::Metrics::ReportMailer).not_to receive(:link_checker_report)
        described_class.perform_now(from_date: from_date, to_date: to_date)
      end
    end
  end
end
