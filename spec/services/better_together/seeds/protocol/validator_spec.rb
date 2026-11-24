# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::Protocol::Validator do
  let(:fixture_dir) { BetterTogether::Engine.root.join('spec/fixtures/seed_packets/minimal') }
  let(:envelope) { YAML.safe_load_file(fixture_dir.join('packet.yml')) }
  let(:records) { YAML.safe_load_file(fixture_dir.join('records/pages.yml')) }
  let(:manifest) { JSON.parse(fixture_dir.join('MANIFEST.json').read) }

  describe '.validate_envelope' do
    it 'accepts the minimal protocol 2.0 packet' do
      expect(described_class.validate_envelope(envelope)).to be_valid
    end

    it 'keeps legacy 1.0 envelopes valid' do
      legacy = YAML.safe_load_file(BetterTogether::Engine.root.join('config/seeds/seed_example.yml'))
      legacy['better_together']['seed']['type'] = 'BetterTogether::Seed'

      expect(described_class.validate_envelope(legacy)).to be_valid
    end

    it 'rejects a legacy envelope missing seed fields' do
      report = described_class.validate_envelope({ 'better_together' => { 'version' => '1.0', 'seed' => {} } })

      expect(report.errors.map(&:field)).to include('/seed/identifier', '/seed/origin')
    end

    it 'reports every problem with a pointer instead of one flattened string' do
      envelope['better_together']['packet']['mode'] = 'overwrite'
      envelope['better_together']['seed_pack']['install_tier'] = 'mandatory'
      envelope['better_together']['packet'].delete('id')

      fields = described_class.validate_envelope(envelope).errors.map(&:field)

      expect(fields).to include('/packet/mode', '/seed_pack/install_tier', '/packet/id')
    end

    it 'requires the default locale to be one of the packet locales' do
      envelope['better_together']['packet']['default_locale'] = 'es'

      report = described_class.validate_envelope(envelope)

      expect(report.errors.map(&:field)).to include('/packet/default_locale')
    end

    it 'rejects a record file outside records/' do
      envelope['better_together']['packet']['records'] = ['../etc/passwd.yml']

      expect(described_class.validate_envelope(envelope)).not_to be_valid
    end

    it 'rejects a pack that depends on itself' do
      envelope['better_together']['seed_pack']['dependencies'] = ['example-minimal-packet']

      expect(described_class.validate_envelope(envelope).errors.map(&:message)).to include(/depend on itself/)
    end

    it 'fails without the root key' do
      expect(described_class.validate_envelope({})).not_to be_valid
    end
  end

  describe '.validate_records' do
    it 'accepts the fixture record file, including both reference forms' do
      records['records'][1]['refs']['grandparent'] = { 'type' => 'page', 'key' => 'about', 'scope' => 'platform' }

      expect(described_class.validate_records(records, file: 'records/pages.yml')).to be_valid
    end

    it 'addresses errors by record key' do
      records['records'][1]['refs']['parent'] = 'not a reference'

      error = described_class.validate_records(records, file: 'records/pages.yml').errors.first

      expect(error.to_h).to include(record: 'about/history', field: '/refs/parent')
    end

    it 'flags duplicate keys within a type' do
      records['records'] << { 'key' => 'about' }

      expect(described_class.validate_records(records).errors.map(&:message)).to include(/duplicate key/)
    end

    it 'flags a blob path that does not match its checksum' do
      records['records'][1]['files'][0]['checksum'] = 'f' * 64

      expect(described_class.validate_records(records).errors.map(&:message)).to include(%r{blobs/<checksum>})
    end

    it 'rejects a filename carrying a path' do
      records['records'][1]['files'][0]['filename'] = '../hero.png'

      expect(described_class.validate_records(records)).not_to be_valid
    end

    it 'rejects unknown record keys' do
      records['records'][0]['sql'] = 'drop table'

      expect(described_class.validate_records(records)).not_to be_valid
    end
  end

  describe '.validate_manifest' do
    it 'accepts the fixture manifest' do
      expect(described_class.validate_manifest(manifest)).to be_valid
    end

    it 'rejects paths outside the packet layout' do
      manifest['files'][0]['path'] = '../secrets.yml'

      expect(described_class.validate_manifest(manifest)).not_to be_valid
    end

    it 'rejects duplicate entries and other algorithms' do
      manifest['files'] << manifest['files'][0].dup
      manifest['algorithm'] = 'md5'

      messages = described_class.validate_manifest(manifest).errors.map(&:message)

      expect(messages).to include(/more than once/, /sha256/)
    end
  end
end
