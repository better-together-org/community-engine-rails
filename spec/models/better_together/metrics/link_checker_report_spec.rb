# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::LinkCheckerReport do
  describe '#generate_csv_file' do
    let(:report) do
      described_class.new(
        file_format: 'csv',
        filters: { 'from_date' => '2025-09-01', 'to_date' => '2025-09-02' }
      )
    end
    let(:file_path) { report.send(:generate_csv_file) }

    before do
      report.report_data = {
        'by_host' => { 'example.com' => 5, 'other.test' => 3 },
        'invalid_by_host' => { 'example.com' => 2, 'other.test' => 1 },
        'failures_daily' => { Date.parse('2025-09-01') => 2, Date.parse('2025-09-02') => 1 }
      }
    end

    it 'creates a CSV with the expected number of rows' do
      csv = CSV.read(file_path)

      expect(csv.size).to eq(7)

      require 'fileutils'
      FileUtils.rm_f(file_path)
    end

    it 'includes host rows with the correct totals' do
      csv = CSV.read(file_path)

      host_rows = csv.select { |r| r[0] == 'example.com' }
      expect(host_rows.first[1]).to eq('5')

      require 'fileutils'
      FileUtils.rm_f(file_path)
    end
  end

  describe '.build_filename' do
    it 'includes the filter stamps and extension' do
      report = described_class.new(file_format: 'csv',
                                   filters: { 'from_date' => '2025-09-01', 'to_date' => '2025-09-02' })
      fn = report.send(:build_filename)

      expect(fn).to match(/LinkCheckerReport_\d{4}-\d{2}-\d{2}_\d{6}_from_2025-09-01_to_2025-09-02.csv/)
    end
  end
end
