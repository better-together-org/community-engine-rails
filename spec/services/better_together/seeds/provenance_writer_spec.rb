# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::ProvenanceWriter do
  let(:platform) { create(:better_together_platform) }
  let(:other_platform) { create(:better_together_platform) }
  let(:dir) { Dir.mktmpdir('seed-provenance') }
  let(:records) { nav_records }

  before { build_packet(dir, id: 'prov-packet', mode: 'upsert', records:) }

  after { FileUtils.remove_entry(dir) }

  def plant(target = platform, apply: true)
    BetterTogether::Seeds::Plant.call(path: dir, platform: target, apply:)
  end

  describe 'after a plant' do
    it 'stores one platform-scoped Seed envelope and links the planting to it', :aggregate_failures do
      plant
      plant(other_platform)

      seeds = BetterTogether::Seed.where(identifier: 'prov-packet')
      expect(seeds.pluck(:platform_id)).to contain_exactly(platform.id, other_platform.id)
      expect(BetterTogether::SeedPlanting.where(platform:).last.seed).to eq(seeds.find_by(platform_id: platform.id))
      expect(seeds.first.payload.keys).to include('packet', 'seed_pack')
    end

    it 'records packet, version, key and fingerprint for every planted record', :aggregate_failures do
      plant

      rows = BetterTogether::SeedProvenance.where(platform:, packet_id: 'prov-packet')
      expect(rows.pluck(:record_type,
                        :record_key)).to contain_exactly(%w[navigation_area main-nav], %w[navigation_item nav-home],
                                                         %w[navigation_item nav-about])
      expect(rows.pluck(:packet_version).uniq).to eq(['1.0.0'])
      expect(rows.pluck(:fingerprint)).to all(match(/\A\h{64}\z/))
    end

    it 'traces a record back to the packet that planted it' do
      plant
      item = BetterTogether::NavigationItem.find_by!(platform:, identifier: 'nav-home')

      expect(BetterTogether::SeedProvenance.for_record(item)).to have_attributes(packet_id: 'prov-packet', record_key: 'nav-home')
    end

    it 'keeps platforms apart and does not duplicate rows on a rerun' do
      plant
      plant(other_platform)

      expect { plant }.not_to change(BetterTogether::SeedProvenance, :count)
      expect(BetterTogether::SeedProvenance.where(platform: other_platform).count).to eq(3)
    end

    it 'updates the fingerprint when upsert changes an unedited record' do
      plant
      before = BetterTogether::SeedProvenance.find_by!(platform:, record_key: 'nav-home').fingerprint
      build_packet(dir, id: 'prov-packet', mode: 'upsert', records: nav_records(title: 'Start'))

      expect(plant).to include(updated: 1, errors: [])
      expect(BetterTogether::SeedProvenance.find_by!(platform:, record_key: 'nav-home').fingerprint).not_to eq(before)
    end

    it 'still treats a steward edit as an edit, using the stored snapshot' do
      plant
      BetterTogether::NavigationItem.find_by!(platform:, identifier: 'nav-home').update!(url: '/edited')
      build_packet(dir, id: 'prov-packet', mode: 'upsert', records: nav_records(title: 'Start'))

      expect(plant[:records]).to include(include(record: 'navigation_item:nav-home', action: :skipped_edited))
    end
  end

  describe 'when a plant fails' do
    let(:records) do
      list = nav_records
      list[:navigation_item][1]['attributes']['url'] = 'javascript:alert(1)'
      list
    end

    it 'writes neither a Seed nor provenance' do
      expect(plant[:errors]).not_to be_empty
      expect(BetterTogether::SeedProvenance.where(platform:)).to be_empty
      expect(BetterTogether::Seed.where(identifier: 'prov-packet', platform_id: platform.id)).to be_empty
    end
  end

  describe 'a dry run' do
    it 'writes neither a Seed nor provenance' do
      plant(apply: false)

      expect(BetterTogether::SeedProvenance.count).to eq(0)
      expect(BetterTogether::Seed.where(identifier: 'prov-packet')).to be_empty
    end
  end
end
