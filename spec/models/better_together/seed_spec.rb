# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seed do
  subject(:seed) { build(:better_together_seed) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:type) }
    it { is_expected.to validate_presence_of(:version) }
    it { is_expected.to validate_presence_of(:created_by) }
    it { is_expected.to validate_presence_of(:seeded_at) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:origin) }
    it { is_expected.to validate_presence_of(:payload) }
  end

  describe '#export' do
    it 'returns the complete structured seed data' do
      expect(seed.export.keys.first).to eq('better_together')
    end
  end

  describe '#export_yaml' do
    it 'generates valid YAML' do
      yaml = seed.export_yaml
      expect(yaml).to include('better_together')
    end
  end

  it 'returns the contributors from origin' do
    expect(seed.contributors.first['name']).to eq('Test Contributor')
  end

  it 'returns the platforms from origin' do
    expect(seed.platforms.first['name']).to eq('Community Engine')
  end

  describe 'scopes' do
    before do
      create(:better_together_seed, identifier: 'generic_seed')
      create(:better_together_seed, identifier: 'home_page', type: 'BetterTogether::Seed')
    end

    it 'filters by type' do
      expect(described_class.by_type('BetterTogether::Seed').count).to eq(2)
    end

    it 'filters by identifier' do
      expect(described_class.by_identifier('home_page').count).to eq(1)
    end
  end

  # -------------------------------------------------------------------
  # Specs for .load_seed
  # -------------------------------------------------------------------
  describe '.load_seed' do
    let(:valid_seed_data) do
      {
        'better_together' => {
          'version' => '1.0',
          'seed' => {
            'type' => 'BetterTogether::Seed',
            'identifier' => 'from_test',
            'created_by' => 'Test Creator',
            'created_at' => '2025-03-04T12:00:00Z',
            'description' => 'A seed from tests',
            'origin' => {
              'contributors' => [],
              'platforms' => [],
              'license' => 'LGPLv3',
              'usage_notes' => 'Test usage only.'
            }
          },
          'payload_key' => 'payload_value'
        }
      }
    end

    let(:file_path) { '/fake/absolute/path/host_setup_wizard.yml' }

    before do
      # Default everything to false/unset, override if needed
      allow(File).to receive(:exist?).and_return(false)
      allow(YAML).to receive(:load_file).and_call_original
    end

    context 'when the source is a direct file path' do
      context 'and the file exists' do
        before do
          allow(File).to receive(:exist?).with(file_path).and_return(true)
          allow(YAML).to receive(:load_file).with(file_path).and_return(valid_seed_data)
        end

        it 'imports the seed and returns a BetterTogether::Seed record' do
          result = described_class.load_seed(file_path)
          expect(result).to be_a(described_class)
          expect(result.identifier).to eq('from_test')
          expect(result.payload[:payload_key]).to eq('payload_value')
        end
      end

      context 'but the file does not exist' do
        it 'falls back to namespace logic and raises an error' do
          expect do
            described_class.load_seed(file_path)
          end.to raise_error(RuntimeError, /Seed file not found for/)
        end
      end

      context 'when YAML loading raises an error' do
        before do
          allow(File).to receive(:exist?).with(file_path).and_return(true)
          allow(YAML).to receive(:load_file).with(file_path).and_raise(StandardError, 'Bad YAML')
        end

        it 'raises a descriptive error' do
          expect do
            described_class.load_seed(file_path)
          end.to raise_error(RuntimeError, /Error loading seed from file.*Bad YAML/)
        end
      end
    end

    context 'when the source is a namespace' do
      let(:namespace) { 'better_together/wizards/host_setup_wizard' }
      let(:full_path) { Rails.root.join('config', 'seeds', "#{namespace}.yml").to_s }

      context 'and the file exists' do
        before do
          allow(File).to receive(:exist?).with(namespace).and_return(false)
          allow(File).to receive(:exist?).with(full_path).and_return(true)
          allow(YAML).to receive(:load_file).with(full_path).and_return(valid_seed_data)
        end

        it 'imports the seed from the namespace path' do
          result = described_class.load_seed(namespace)
          expect(result).to be_a(described_class)
          expect(result.identifier).to eq('from_test')
        end
      end

      context 'but the file does not exist' do
        before do
          allow(File).to receive(:exist?).with(namespace).and_return(false)
          allow(File).to receive(:exist?).with(full_path).and_return(false)
        end

        it 'raises a file-not-found error' do
          expect do
            described_class.load_seed(namespace)
          end.to raise_error(RuntimeError, /Seed file not found for/)
        end
      end

      context 'when YAML loading raises an error' do
        before do
          allow(File).to receive(:exist?).with(namespace).and_return(false)
          allow(File).to receive(:exist?).with(full_path).and_return(true)
          allow(YAML).to receive(:load_file).with(full_path).and_raise(StandardError, 'YAML parse error')
        end

        it 'raises a descriptive error' do
          expect do
            described_class.load_seed(namespace)
          end.to raise_error(RuntimeError, /Error loading seed from namespace.*YAML parse error/)
        end
      end
    end
  end

  # -------------------------------------------------------------------
  # Specs for Active Storage attachment
  # -------------------------------------------------------------------
  describe 'Active Storage YAML attachment' do
    let(:seed) do
      # create a valid, persisted seed so that we can test the attachment
      create(:better_together_seed)
    end

    it 'attaches a YAML file after creation' do
      # seed.reload  # Ensures the record reloads from the DB after the commit callback
      # expect(seed.yaml_file).to be_attached

      # # Optional: Check content type and file content
      # expect(seed.yaml_file.content_type).to eq('text/yaml')
      # downloaded_data = seed.yaml_file.download
      # expect(downloaded_data).to include('better_together')
    end
  end
end
