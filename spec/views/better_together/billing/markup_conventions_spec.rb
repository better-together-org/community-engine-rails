# frozen_string_literal: true

require 'rails_helper'

# Static guards for the billing templates: every data table is captioned, breadcrumbs are translated, and dates
# go through the nil-safe <time> helper.
RSpec.describe 'Billing template conventions' do # rubocop:disable RSpec/DescribeClass
  let(:files) do
    Dir[BetterTogether::Engine.root.join('app/views/better_together/billing/**/*.erb')] +
      Dir[BetterTogether::Engine.root.join('app/views/better_together/metrics/reports/_billing_summary.html.erb')]
  end

  def lines_of(file) = File.read(file).split("\n")

  it 'gives every table a caption' do
    uncaptioned = files.flat_map do |file|
      lines = lines_of(file)
      lines.each_index.select { |i| lines[i].include?('<table') && lines[i, 3].none? { |line| line.include?('<caption') } }
           .map { |i| "#{File.basename(file)}:#{i + 1}" }
    end

    expect(uncaptioned).to be_empty
  end

  it 'translates the breadcrumb label' do
    expect(files.select { |file| File.read(file).include?('aria-label="breadcrumb"') }).to be_empty
  end

  it 'prints dates with the nil-safe time helper' do
    raw = files.select { |file| File.read(file).match?(/<%=[^%]*\bl\([^)]*format:/) }

    expect(raw).to be_empty
  end
end
