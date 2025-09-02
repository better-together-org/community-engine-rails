# frozen_string_literal: true

require 'rails_helper'

class ReportPORO
  # Minimal PORO reproducing CSV and filename logic so tests run without ActiveRecord
  attr_accessor :report_data, :file_format, :filters

  # These methods are intentionally slightly large for test clarity. Disable
  # Metrics cops which are noisy for PORO test helpers.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def initialize(filters: {}, file_format: 'csv')
    @filters = filters
    @file_format = file_format
    @report_data = {}
  end

  def build_filename
    filters_summary = []

    if filters['from_date'].present?
      from_stamp = Date.parse(filters['from_date']).strftime('%Y-%m-%d')
      filters_summary << "from_#{from_stamp}"
    end

    if filters['to_date'].present?
      to_stamp = Date.parse(filters['to_date']).strftime('%Y-%m-%d')
      filters_summary << "to_#{to_stamp}"
    end

    filters_summary = filters_summary.join('_')
    filters_summary = 'all' if filters_summary.blank?

    timestamp = Time.current.strftime('%Y-%m-%d_%H%M%S')

    "LinkCheckerReport_#{timestamp}_#{filters_summary}.#{file_format}"
  end

  def generate_csv_file
    file_path = Rails.root.join('tmp', build_filename)

    CSV.open(file_path, 'w') do |csv|
      csv << ['Host', 'Total Links', 'Invalid Links']

      hosts = (report_data['by_host'] || {}).keys
      hosts.each do |host|
        total = (report_data['by_host'] || {})[host] || 0
        invalid = (report_data['invalid_by_host'] || {})[host] || 0
        csv << [host, total, invalid]
      end

      csv << []
      csv << ['Date', 'Invalid Count']
      (report_data['failures_daily'] || {}).each do |date, count|
        csv << [date.to_s, count]
      end
    end

    file_path
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end

RSpec.describe ReportPORO do # rubocop:disable RSpec/SpecFilePathFormat
  describe 'CSV generation and filename' do
    let(:report) do
      described_class.new(filters: { 'from_date' => '2025-09-01', 'to_date' => '2025-09-02' })
    end

    before do
      report.report_data = {
        'by_host' => { 'example.com' => 5, 'other.test' => 3 },
        'invalid_by_host' => { 'example.com' => 2, 'other.test' => 1 },
        'failures_daily' => { Date.parse('2025-09-01') => 2, Date.parse('2025-09-02') => 1 }
      }
    end

    it 'creates a CSV with the expected rows' do
      file_path = report.generate_csv_file
      csv = CSV.read(file_path)

      expect(csv.size).to eq(7)

      require 'fileutils'
      FileUtils.rm_f(file_path)
    end

    it 'builds a filename with stamps and extension' do
      fn = report.build_filename
      expect(fn).to match(/LinkCheckerReport_\d{4}-\d{2}-\d{2}_\d{6}_from_2025-09-01_to_2025-09-02.csv/)
    end
  end
end
