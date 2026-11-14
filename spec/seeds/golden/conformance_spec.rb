# frozen_string_literal: true

require 'rails_helper'

# Protocol 2.0 conformance: each example plants a golden packet through the public entry point
# (Seeds::Plant) and asserts the structured report plus what did or did not reach the database.
RSpec.describe 'Seed packet conformance' do # rubocop:disable RSpec/DescribeClass
  include SeedBlobHelpers

  let(:platform) { create(:better_together_platform) }
  let(:dir) { Dir.mktmpdir('seed-golden') }
  let(:pdf) { "%PDF-1.4\n#{'golden ' * 50}" }

  after { FileUtils.remove_entry(dir) }

  def plant(apply: true, target: platform, path: dir, **)
    BetterTogether::Seeds::Plant.call(path:, platform: target, apply:, **)
  end

  def nav_count(target = platform)
    BetterTogether::NavigationItem.where(platform: target, identifier: %w[nav-home nav-about]).count
  end

  def upload_packet(bytes: pdf)
    sha = write_blob(dir, bytes)
    records = { upload: [{ 'key' => 'guide', 'attributes' => { 'privacy' => 'private' },
                           'translations' => { 'en' => { 'name' => 'Guide' } },
                           'files' => [{ 'attachment' => 'file', 'blob' => "blobs/#{sha}", 'filename' => 'guide.pdf',
                                         'content_type' => 'application/pdf', 'checksum' => sha }] }] }
    build_packet(dir, records:)
    write_manifest(dir)
    sha
  end

  describe 'navigation packet' do
    before { build_packet(dir, records: nav_records) }

    it 'plants on an empty platform' do
      expect(plant).to include(created: 3, errors: [], dry_run: false)
      expect(nav_count).to eq(2)
    end

    it 'reports no changes on a rerun' do
      plant
      expect(plant).to include(created: 0, updated: 0, unchanged: 3)
    end

    it 'dry run writes nothing' do
      expect(plant(apply: false)).to include(created: 3, dry_run: true)
      expect(nav_count).to eq(0)
      expect(BetterTogether::SeedPlanting.count).to eq(0)
    end

    it 'keeps two platforms apart' do
      other = create(:better_together_platform)
      plant
      plant(target: other)

      expect(nav_count).to eq(2)
      expect(nav_count(other)).to eq(2)
      ids = ->(target) { BetterTogether::NavigationItem.where(platform: target).pluck(:id) }
      expect(ids.call(platform) & ids.call(other)).to be_empty
    end

    it 'skips a steward-edited record on a changed rerun' do
      plant
      BetterTogether::NavigationItem.find_by!(platform:, identifier: 'nav-home').update!(title: 'Mine')
      build_packet(dir, mode: 'upsert', records: nav_records(title: 'New'))

      expect(plant).to include(skipped_edited: 1, updated: 0)
    end
  end

  it 'writes nothing when a reference is missing' do
    records = nav_records
    records[:navigation_item][0]['refs']['navigation_area'] = 'navigation_area:nope'
    build_packet(dir, records:)

    report = plant

    expect(report[:errors]).not_to be_empty
    expect(nav_count).to eq(0)
  end

  describe 'locale policy' do
    it 'fails on an undeclared locale by default and skips it when told to' do
      records = nav_records
      records[:navigation_item][0]['translations']['de'] = { 'title' => 'Start' }
      build_packet(dir, records:)
      expect(plant(apply: false)[:errors]).not_to be_empty

      build_packet(dir, records:, extra_packet: { 'unsupported_locale_policy' => 'skip' })
      expect(plant(apply: false)).to include(errors: [])
    end
  end

  describe 'blob transport through Plant' do
    it 'attaches a verified file' do
      upload_packet

      expect(plant).to include(created: 1, errors: [])
      file = BetterTogether::Upload.find_by!(platform:, identifier: 'guide').file
      expect(file).to be_attached
      expect([file.filename.to_s, file.blob.byte_size]).to eq(['guide.pdf', pdf.bytesize])
    end

    it 'rejects a tampered blob and writes nothing' do
      sha = upload_packet
      File.binwrite(File.join(dir, 'blobs', sha), pdf.reverse)

      report = plant

      expect(report[:errors].map { |e| e[:message] }.join).to match(/sha256|size/)
      expect(BetterTogether::Upload.where(platform:, identifier: 'guide')).to be_empty
    end

    it 'fails closed when records declare files and there is no manifest' do
      upload_packet
      FileUtils.rm(File.join(dir, 'MANIFEST.json'))

      expect(plant[:errors].map { |e| e[:message] }.join).to include('no MANIFEST.json')
    end

    it 'plants from a tar.gz' do
      upload_packet
      archive = File.join(Dir.mktmpdir('seed-golden-archive'), 'packet.tar.gz')
      tar_gz(archive, Dir.glob('**/*', base: dir).select { |f| File.file?(File.join(dir, f)) }.map { |f| [f, File.binread(File.join(dir, f))] })

      expect(plant(path: archive)).to include(created: 1, errors: [])
    end
  end

  describe 'packet source allowlist' do
    before { build_packet(dir, records: nav_records) }

    it 'refuses a packet outside the allowed roots when restricted' do
      expect { plant(restrict_sources: true) }.to raise_error(BetterTogether::Seeds::PacketSources::Forbidden)
    end

    it 'accepts a registered root' do
      BetterTogether::Seeds::PacketSources.register_root(File.dirname(dir))
      expect(plant(restrict_sources: true)).to include(created: 3)
    ensure
      BetterTogether::Seeds::PacketSources.reset!
    end
  end
end
