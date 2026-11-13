# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::Plant do
  let(:platform) { create(:better_together_platform) }
  let(:dir) { Dir.mktmpdir('seed-packet') }
  let(:records) { nav_records }
  let(:mode) { 'add_only' }
  let(:other_options) { {} }

  before { build_packet(dir, mode:, records:, **other_options) }

  after { FileUtils.remove_entry(dir) }

  def plant(apply: true, target: platform)
    described_class.call(path: dir, platform: target, apply:)
  end

  def area_items(target = platform)
    BetterTogether::NavigationItem.where(platform: target).where(identifier: %w[nav-home nav-about])
  end

  describe 'dry run' do
    it 'reports the plan and writes nothing, not even a planting' do
      report = plant(apply: false)

      expect(report).to include(dry_run: true, created: 3, errors: [])
      expect(BetterTogether::NavigationArea.where(platform:, identifier: 'main-nav')).to be_empty
      expect(BetterTogether::SeedPlanting.count).to eq(0)
    end

    it 'is the default for apply' do
      expect(described_class.call(path: dir, platform:)).to include(dry_run: true)
    end
  end

  describe 'apply' do
    it 'creates records in dependency order with references, translations and positions' do
      report = plant

      expect(report).to include(created: 3, errors: [], dry_run: false)
      home = area_items.find_by(identifier: 'nav-home')
      about = area_items.find_by(identifier: 'nav-about')
      expect(about.parent).to eq(home)
      expect(about.navigation_area.identifier).to eq('main-nav')
      expect(Mobility.with_locale(:fr) { home.title }).to eq('Accueil')
      expect(about.position).to eq(1)
    end

    it 'records a completed planting with per-record provenance' do
      plant

      planting = BetterTogether::SeedPlanting.last
      expect(planting).to be_completed
      expect(planting.platform).to eq(platform)
      expect(planting.result['provenance'].keys).to contain_exactly(
        'navigation_area:main-nav', 'navigation_item:nav-home', 'navigation_item:nav-about'
      )
    end

    it 'reports unchanged on an identical rerun' do
      plant

      expect(plant).to include(created: 0, updated: 0, unchanged: 3, skipped_edited: 0)
    end
  end

  context 'with upsert mode' do
    let(:mode) { 'upsert' }

    it 'updates an unedited planted record when the packet changes' do
      plant
      build_packet(dir, mode:, records: nav_records(title: 'Start'))

      expect(plant).to include(updated: 1, unchanged: 2)
      expect(area_items.find_by(identifier: 'nav-home').title).to eq('Start')
    end

    it 'leaves a steward-edited record alone and says so' do
      plant
      area_items.find_by(identifier: 'nav-home').update!(title: 'Steward title')
      build_packet(dir, mode:, records: nav_records(title: 'Start'))

      report = plant

      expect(report).to include(updated: 0, skipped_edited: 1)
      expect(area_items.find_by(identifier: 'nav-home').title).to eq('Steward title')
    end
  end

  context 'with add_only mode and a changed packet' do
    it 'never touches existing records' do
      plant
      build_packet(dir, mode:, records: nav_records(title: 'Start'))

      expect(plant).to include(updated: 0, skipped_edited: 1)
    end
  end

  context 'with managed mode and a tombstone' do
    let(:mode) { 'managed' }

    it 'deletes only records the packet planted and nobody edited' do
      plant
      build_packet(dir, mode:, records: { navigation_area: nav_records[:navigation_area] },
                        deletes: [{ 'type' => 'navigation_item', 'key' => 'nav-about' }])

      report = plant

      expect(report).to include(deleted: 1)
      expect(area_items.pluck(:identifier)).to eq([]).or contain_exactly('nav-home')
      expect(BetterTogether::NavigationItem.where(platform:, identifier: 'nav-about')).to be_empty
    end

    it 'skips a tombstone for an edited record' do
      plant
      area_items.find_by(identifier: 'nav-about').update!(title: 'Edited')
      build_packet(dir, mode:, records: { navigation_area: nav_records[:navigation_area] },
                        deletes: [{ 'type' => 'navigation_item', 'key' => 'nav-about' }])

      expect(plant).to include(deleted: 0, skipped_edited: 1)
      expect(BetterTogether::NavigationItem.where(platform:, identifier: 'nav-about')).to exist
    end
  end

  context 'with a reference that cannot be resolved' do
    let(:records) do
      list = nav_records
      list[:navigation_item][0]['refs']['navigation_area'] = 'navigation_area:nope'
      list
    end

    it 'fails the plan before any write and names the field' do
      report = plant

      expect(report[:errors]).to include(include(record: 'navigation_item:nav-home', field: '/refs/navigation_area'))
      expect(BetterTogether::NavigationArea.where(platform:, identifier: 'main-nav')).to be_empty
      expect(BetterTogether::SeedPlanting.count).to eq(0)
    end
  end

  context 'with a field the registry does not allow' do
    let(:records) do
      list = nav_records
      list[:navigation_item][0]['attributes']['protected'] = true
      list
    end

    it 'rejects the record instead of assigning it' do
      expect(plant[:errors]).to include(include(field: '/attributes/protected'))
    end
  end

  context 'with an invalid record' do
    let(:records) do
      list = nav_records
      list[:navigation_item][1]['attributes']['url'] = 'javascript:alert(1)'
      list
    end

    it 'reports the model error per record and rolls the whole packet back' do
      report = plant

      expect(report[:errors]).to include(include(record: 'navigation_item:nav-about'))
      expect(report).to include(rolled_back: true, created: 0)
      expect(BetterTogether::NavigationArea.where(platform:, identifier: 'main-nav')).to be_empty
      expect(BetterTogether::SeedPlanting.last).to be_failed
    end
  end

  context 'with a locale the packet does not declare' do
    let(:records) do
      list = nav_records
      list[:navigation_item][0]['translations']['es'] = { 'title' => 'Inicio' }
      list
    end

    it 'fails under the default policy' do
      expect(plant(apply: false)[:errors]).to include(include(field: '/translations/es'))
    end

    context 'when the policy is skip' do
      let(:other_options) { { extra_packet: { 'unsupported_locale_policy' => 'skip' } } }

      it 'drops the locale with a warning' do
        report = plant(apply: false)

        expect(report[:errors]).to be_empty
        expect(report[:warnings]).to include(include(field: '/translations/es'))
      end
    end
  end

  context 'with a packet that declares another platform' do
    let(:other_options) { { extra_packet: { 'target' => { 'platform_identifier' => 'someone-else' } } } }

    it 'refuses to plant on the wrong platform' do
      expect(plant[:errors].first[:message]).to include('targets someone-else')
    end
  end

  context 'with a missing pack dependency' do
    let(:other_options) { { depends: ['core-missing'] } }

    it 'fails closed' do
      expect(plant[:errors].first[:message]).to include('core-missing is not planted')
    end
  end

  context 'with files but no blob transport' do
    let(:records) do
      {
        upload: [{ 'key' => 'doc', 'attributes' => { 'privacy' => 'private' },
                   'files' => [{ 'attachment' => 'file', 'blob' => "blobs/#{'a' * 64}", 'filename' => 'a.pdf',
                                 'content_type' => 'application/pdf', 'checksum' => 'a' * 64 }] }]
      }
    end

    it 'fails closed per record' do
      expect(plant[:errors].first[:message]).to include('blob transport')
    end
  end

  context 'with an invalid packet' do
    it 'returns validation errors with file and pointer' do
      File.write(File.join(dir, 'records/navigation_item.yml'),
                 { 'version' => '2.0', 'type' => 'navigation_item', 'records' => [{ 'key' => '!!' }] }.to_yaml)

      expect(plant[:errors]).to include(include(record: 'records/navigation_item.yml !!', field: '/key'))
    end

    it 'rejects a symbolic link inside the packet' do
      File.symlink('/etc/hostname', File.join(dir, 'evil.yml'))

      expect(plant[:errors].first[:message]).to include('symbolic link')
    end
  end
end
