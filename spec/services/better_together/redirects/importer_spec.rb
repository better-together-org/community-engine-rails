# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Redirects::Importer do
  let(:platform) { create(:better_together_platform) }
  let(:rows) do
    [{ from_path: '/a.html', to_path: '/en/a' },
     { from_path: '/b.pdf', to_path: '/en/f/b', status: '308' },
     { from_path: '/bad', to_path: 'javascript:x' }]
  end

  it 'writes nothing on a dry run and reports what would happen' do
    report = described_class.call(platform:, rows:, dry_run: true)

    expect(platform.redirects.count).to eq(0)
    expect([report.created, report.errors.size, report.dry_run]).to eq([2, 1, true])
  end

  it 'creates valid rows when applied, with the given source and status' do
    report = described_class.call(platform:, rows:, source: 'seed', dry_run: false)

    expect(report.created).to eq(2)
    expect(platform.redirects.find_by(from_path: '/b.pdf')).to have_attributes(status: 308, source: 'seed')
  end

  it 'skips existing rows in add_only mode and updates them in upsert mode' do
    create(:better_together_redirect, platform:, from_path: '/a.html', to_path: '/en/old')

    skipped = described_class.call(platform:, rows: rows.first(1), dry_run: false)
    expect([skipped.skipped, platform.redirects.first.to_path]).to eq([1, '/en/old'])

    updated = described_class.call(platform:, rows: rows.first(1), mode: :upsert, dry_run: false)
    expect([updated.updated, platform.redirects.first.to_path]).to eq([1, '/en/a'])
  end

  it 'reports an unchanged row on a repeat upsert' do
    described_class.call(platform:, rows: rows.first(1), dry_run: false)

    report = described_class.call(platform:, rows: rows.first(1), mode: :upsert, dry_run: false)

    expect(report.unchanged).to eq(1)
  end
end
