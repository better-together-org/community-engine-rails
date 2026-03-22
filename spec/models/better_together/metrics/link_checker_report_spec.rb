# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ClassLength
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
      # Report summary
      csv << ['Link Checker Report Summary']
      csv << ['Generated', Time.current.utc.strftime('%Y-%m-%d %H:%M UTC')]
      csv << ['Total Broken Links', total_broken_links]
      csv << []
      csv << ['Broken Links by Record Type']
      csv << []

      # Grouped broken links details
      grouped = broken_links_grouped_by_type
      grouped.each do |record_type, links|
        csv << ["#{record_type.upcase} (#{links.size} broken links)"]
        csv << ['Record', 'Field', 'Broken URL', 'Status', 'Error', 'Last Checked', 'Edit URL', 'Instructions']

        links.each do |link|
          csv << [
            link['record_identifier'] || link[:record_identifier],
            link['field_name'] || link[:field_name],
            link['url'] || link[:url],
            link['status_code'] || link[:status_code],
            link['error_message'] || link[:error_message],
            link['last_checked_at'] || link[:last_checked_at],
            link['edit_url'] || link[:edit_url] || 'N/A',
            link['edit_instructions'] || link[:edit_instructions]
          ]
        end

        csv << []
      end

      # Summary by host
      csv << ['Summary by Host']
      csv << ['Host', 'Total Links', 'Invalid Links']

      hosts = (report_data['by_host'] || {}).keys
      hosts.each do |host|
        total = (report_data['by_host'] || {})[host] || 0
        invalid = (report_data['invalid_by_host'] || {})[host] || 0
        csv << [host, total, invalid]
      end

      # Failures by date
      csv << []
      csv << ['Failures by Date']
      csv << ['Date', 'Invalid Count']
      (report_data['failures_daily'] || {}).each do |date, count|
        csv << [date.to_s, count]
      end
    end

    file_path
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # Check if report has no broken links
  def no_broken_links?
    invalid_by_host = extract_invalid_by_host
    invalid_by_host.values.sum.zero?
  end

  # Deprecated: Use no_broken_links? instead
  alias has_no_broken_links? no_broken_links?

  # Check if broken links have changed compared to another report
  def broken_links_changed_since?(other_report)
    return true if other_report.nil?

    current_invalid = extract_invalid_by_host
    previous_invalid = extract_invalid_by_host_from(other_report)

    # Compare the sets of broken links by host
    current_invalid != previous_invalid
  end

  def extract_invalid_by_host
    report_data&.dig('invalid_by_host') || report_data&.dig(:invalid_by_host) || {}
  end

  def extract_invalid_by_host_from(other_report)
    other_report.report_data&.dig('invalid_by_host') ||
      other_report.report_data&.dig(:invalid_by_host) || {}
  end

  # Get total count of broken links
  def total_broken_links
    invalid_by_host = extract_invalid_by_host
    invalid_by_host.values.sum
  end

  # Group broken links by record type
  def broken_links_grouped_by_type
    broken_links = report_data&.dig('broken_links') || report_data&.dig(:broken_links) || []
    broken_links.group_by { |link| link['record_type'] || link[:record_type] }
  end

  # Humanize record type (strip namespace)
  def humanize_record_type(type)
    parts = type.to_s.split('::')
    # For nested modules like "BetterTogether::Content::Block", keep "Content Block"
    # For simple modules like "BetterTogether::Person", keep "Person"
    if parts.size > 2 && parts.first == 'BetterTogether'
      parts[1..].join(' ')
    else
      parts.last
    end
  end

  # Get identifier for a record
  def record_identifier(record)
    return record.name if record.respond_to?(:name)
    return record.title if record.respond_to?(:title)
    return record.identifier if record.respond_to?(:identifier)

    "ID: #{record.id}"
  end

  # Extract field name from ActionText rich_text
  def field_name_from_rich_text(rich_text, _record)
    rich_text.name&.humanize || 'Unknown'
  end

  # Generate edit instructions for record
  def edit_instructions_for(record)
    return "Edit Person profile (#{record.name})" if record.is_a?(BetterTogether::Person)

    "Edit #{record.class.name.demodulize} record"
  end
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
        'failures_daily' => { Date.parse('2025-09-01') => 2, Date.parse('2025-09-02') => 1 },
        'broken_links' => [
          {
            'record_type' => 'Person',
            'record_identifier' => 'John',
            'field_name' => 'Description',
            'url' => 'http://broken.link',
            'status_code' => '404',
            'error_message' => 'Not Found',
            'last_checked_at' => '2025-09-01 10:00 UTC',
            'edit_url' => 'http://example.com/people/1/edit',
            'edit_instructions' => 'Edit Person profile (John)'
          }
        ]
      }
    end

    it 'creates a CSV with the expected rows' do
      file_path = report.generate_csv_file
      csv = CSV.read(file_path)

      # Verify summary section exists
      expect(csv[0][0]).to eq('Link Checker Report Summary')
      expect(csv[2][0]).to eq('Total Broken Links')

      require 'fileutils'
      FileUtils.rm_f(file_path)
    end

    it 'builds a filename with stamps and extension' do
      fn = report.build_filename
      expect(fn).to match(/LinkCheckerReport_\d{4}-\d{2}-\d{2}_\d{6}_from_2025-09-01_to_2025-09-02.csv/)
    end
  end

  describe '#has_no_broken_links?' do
    it 'returns true when there are no invalid links' do
      report = described_class.new
      report.report_data = { 'invalid_by_host' => {} }
      expect(report.has_no_broken_links?).to be true
    end

    it 'returns false when there are invalid links' do
      report = described_class.new
      report.report_data = { 'invalid_by_host' => { 'example.com' => 2 } }
      expect(report.has_no_broken_links?).to be false
    end

    it 'handles symbolized keys' do
      report = described_class.new
      report.report_data = { invalid_by_host: { 'example.com' => 1 } }
      expect(report.has_no_broken_links?).to be false
    end
  end

  describe '#total_broken_links' do
    it 'returns sum of all broken links across hosts' do
      report = described_class.new
      report.report_data = {
        'invalid_by_host' => {
          'example.com' => 2,
          'other.test' => 3,
          'broken.site' => 1
        }
      }
      expect(report.total_broken_links).to eq(6)
    end

    it 'returns 0 when no broken links' do
      report = described_class.new
      report.report_data = { 'invalid_by_host' => {} }
      expect(report.total_broken_links).to eq(0)
    end
  end

  describe '#broken_links_changed_since?' do
    let(:old_report) do
      report = described_class.new
      report.report_data = {
        'invalid_by_host' => { 'example.com' => 2, 'other.test' => 1 }
      }
      report
    end

    it 'returns true when broken links differ' do
      new_report = described_class.new
      new_report.report_data = {
        'invalid_by_host' => { 'example.com' => 3, 'other.test' => 1 }
      }
      expect(new_report.broken_links_changed_since?(old_report)).to be true
    end

    it 'returns false when broken links are the same' do
      new_report = described_class.new
      new_report.report_data = {
        'invalid_by_host' => { 'example.com' => 2, 'other.test' => 1 }
      }
      expect(new_report.broken_links_changed_since?(old_report)).to be false
    end

    it 'returns true when nil is passed' do
      new_report = described_class.new
      new_report.report_data = { 'invalid_by_host' => { 'example.com' => 1 } }
      expect(new_report.broken_links_changed_since?(nil)).to be true
    end
  end

  describe '#broken_links_grouped_by_type' do
    it 'groups broken links by record type' do
      report = described_class.new
      report.report_data = {
        'broken_links' => [
          { 'record_type' => 'Person', 'record_identifier' => 'John' },
          { 'record_type' => 'Person', 'record_identifier' => 'Jane' },
          { 'record_type' => 'Community', 'record_identifier' => 'Seattle' }
        ]
      }

      grouped = report.broken_links_grouped_by_type
      expect(grouped.keys).to match_array(%w[Person Community])
      expect(grouped['Person'].size).to eq(2)
      expect(grouped['Community'].size).to eq(1)
    end

    it 'returns empty hash when no broken links' do
      report = described_class.new
      report.report_data = { 'broken_links' => [] }
      expect(report.broken_links_grouped_by_type).to eq({})
    end

    it 'handles missing broken_links key' do
      report = described_class.new
      report.report_data = {}
      expect(report.broken_links_grouped_by_type).to eq({})
    end
  end

  describe '#humanize_record_type' do
    it 'extracts simple class name from namespaced class' do
      report = described_class.new
      expect(report.humanize_record_type('BetterTogether::Person')).to eq('Person')
    end

    it 'handles already simple class names' do
      report = described_class.new
      expect(report.humanize_record_type('Person')).to eq('Person')
    end

    it 'handles nested modules by keeping last two parts' do
      report = described_class.new
      expect(report.humanize_record_type('BetterTogether::Content::Block')).to eq('Content Block')
    end
  end

  describe '#record_identifier' do
    it 'returns name attribute when present' do
      record = double(respond_to?: true, name: 'John Doe')
      allow(record).to receive(:respond_to?).with(:name).and_return(true)

      report = described_class.new
      expect(report.record_identifier(record)).to eq('John Doe')
    end

    it 'returns title when name not present' do
      record = double(respond_to?: false, title: 'My Post')
      allow(record).to receive(:respond_to?).with(:name).and_return(false)
      allow(record).to receive(:respond_to?).with(:title).and_return(true)

      report = described_class.new
      expect(report.record_identifier(record)).to eq('My Post')
    end

    it 'returns identifier when name and title not present' do
      record = double(respond_to?: false, identifier: 'my-block')
      allow(record).to receive(:respond_to?).with(:name).and_return(false)
      allow(record).to receive(:respond_to?).with(:title).and_return(false)
      allow(record).to receive(:respond_to?).with(:identifier).and_return(true)

      report = described_class.new
      expect(report.record_identifier(record)).to eq('my-block')
    end

    it 'returns ID string as fallback' do
      record = double(respond_to?: false, id: 123)
      allow(record).to receive(:respond_to?).with(:name).and_return(false)
      allow(record).to receive(:respond_to?).with(:title).and_return(false)
      allow(record).to receive(:respond_to?).with(:identifier).and_return(false)

      report = described_class.new
      expect(report.record_identifier(record)).to eq('ID: 123')
    end
  end

  describe '#field_name_from_rich_text' do
    it 'extracts humanized field name from ActionText name' do
      rich_text = double(name: 'description')
      record = double

      report = described_class.new
      expect(report.field_name_from_rich_text(rich_text, record)).to eq('Description')
    end

    it 'returns Unknown when name is nil' do
      rich_text = double(name: nil)
      record = double

      report = described_class.new
      expect(report.field_name_from_rich_text(rich_text, record)).to eq('Unknown')
    end
  end

  describe '#edit_instructions_for' do
    it 'returns specific instructions for Person' do
      person = double(class: BetterTogether::Person, name: 'John')
      allow(person).to receive(:is_a?).with(BetterTogether::Person).and_return(true)
      allow(person).to receive(:respond_to?).with(:name).and_return(true)

      report = described_class.new
      expect(report.edit_instructions_for(person)).to eq('Edit Person profile (John)')
    end

    it 'returns generic instructions for unknown types' do
      record = double(class: Object)
      allow(record).to receive_messages(is_a?: false, class: Object)

      report = described_class.new
      expect(report.edit_instructions_for(record)).to eq('Edit Object record')
    end
  end
end
# rubocop:enable Metrics/ClassLength
