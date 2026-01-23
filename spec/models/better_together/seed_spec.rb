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

    let(:file_path) { Rails.root.join('config', 'seeds', 'test_seed.yml').to_s }

    before do
      # Default everything to false/unset, override if needed
      allow(File).to receive(:exist?).and_return(false)
      allow(described_class).to receive(:safe_load_yaml_file).and_call_original
    end

    context 'when the source is a direct file path' do
      # rubocop:todo RSpec/NestedGroups
      context 'and the file exists' do # rubocop:todo RSpec/ContextWording, RSpec/NestedGroups
        # rubocop:enable RSpec/NestedGroups
        before do
          allow(File).to receive(:exist?).with(file_path).and_return(true)
          allow(File).to receive(:size).with(file_path).and_return(1024) # Mock file size
          allow(described_class).to receive(:safe_load_yaml_file).with(file_path).and_return(valid_seed_data)
        end

        it 'imports the seed and returns a BetterTogether::Seed record' do # rubocop:todo RSpec/MultipleExpectations
          result = described_class.load_seed(file_path)
          expect(result).to be_a(described_class)
          expect(result.identifier).to eq('from_test')
          expect(result.payload[:payload_key]).to eq('payload_value')
        end
      end

      # rubocop:todo RSpec/NestedGroups
      context 'but the file does not exist' do # rubocop:todo RSpec/ContextWording, RSpec/NestedGroups
        # rubocop:enable RSpec/NestedGroups
        it 'falls back to namespace logic and raises an error' do
          expect do
            described_class.load_seed(file_path)
          end.to raise_error(RuntimeError, /Seed file not found for/)
        end
      end

      context 'when YAML loading raises an error' do # rubocop:todo RSpec/NestedGroups
        before do
          allow(File).to receive(:exist?).with(file_path).and_return(true)
          allow(File).to receive(:size).with(file_path).and_return(1024) # Mock file size
          allow(described_class).to receive(:safe_load_yaml_file).with(file_path).and_raise(StandardError, 'Bad YAML')
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

      # rubocop:todo RSpec/NestedGroups
      context 'and the file exists' do # rubocop:todo RSpec/ContextWording, RSpec/NestedGroups
        # rubocop:enable RSpec/NestedGroups
        before do
          allow(File).to receive(:exist?).with(namespace).and_return(false)
          allow(File).to receive(:exist?).with(full_path).and_return(true)
          allow(File).to receive(:size).with(full_path).and_return(1024) # Mock file size
          allow(described_class).to receive(:safe_load_yaml_file).with(full_path).and_return(valid_seed_data)
        end

        it 'imports the seed from the namespace path' do # rubocop:todo RSpec/MultipleExpectations
          result = described_class.load_seed(namespace)
          expect(result).to be_a(described_class)
          expect(result.identifier).to eq('from_test')
        end
      end

      # rubocop:todo RSpec/NestedGroups
      context 'but the file does not exist' do # rubocop:todo RSpec/ContextWording, RSpec/NestedGroups
        # rubocop:enable RSpec/NestedGroups
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

      context 'when YAML loading raises an error' do # rubocop:todo RSpec/NestedGroups
        before do
          allow(File).to receive(:exist?).with(namespace).and_return(false)
          allow(File).to receive(:exist?).with(full_path).and_return(true)
          allow(File).to receive(:size).with(full_path).and_return(1024) # Mock file size
          allow(described_class).to receive(:safe_load_yaml_file).with(full_path).and_raise(StandardError,
                                                                                            'YAML parse error')
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

    it 'attaches a YAML file after creation' do # rubocop:todo RSpec/NoExpectationExample
      # seed.reload  # Ensures the record reloads from the DB after the commit callback
      # expect(seed.yaml_file).to be_attached

      # # Optional: Check content type and file content
      # expect(seed.yaml_file.content_type).to eq('text/yaml')
      # downloaded_data = seed.yaml_file.download
      # expect(downloaded_data).to include('better_together')
    end
  end

  describe 'SeedPlanting integration' do
    before do
      configure_host_platform
    end

    let(:person) { create(:better_together_person) }

    describe 'associations' do
      it { is_expected.to have_many(:seed_plantings).class_name('BetterTogether::SeedPlanting') }
    end

    describe '.plant_with_validation with planting tracking' do
      let(:valid_seed_data) do
        {
          'better_together' => {
            'version' => '1.0',
            'seed' => {
              'type' => 'BetterTogether::Seed',
              'identifier' => 'test_seed',
              'created_by' => 'Test User',
              'created_at' => Time.current.iso8601,
              'description' => 'Test seed for planting',
              'origin' => {
                'contributors' => [{ 'name' => 'Test', 'role' => 'Developer' }],
                'platforms' => [{ 'name' => 'Test Platform', 'version' => '1.0' }]
              }
            },
            'data' => { 'test' => 'value' }
          }
        }
      end

      context 'with tracking enabled' do # rubocop:todo RSpec/NestedGroups
        it 'creates a SeedPlanting record' do # rubocop:todo RSpec/ExampleLength
          expect do
            described_class.plant_with_validation(
              valid_seed_data,
              track_planting: true,
              planted_by: person
            )
          end.to change(BetterTogether::SeedPlanting, :count).by(1)
        end

        # rubocop:todo RSpec/MultipleExpectations
        it 'marks planting as completed on success' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
          # rubocop:enable RSpec/MultipleExpectations
          described_class.plant_with_validation(
            valid_seed_data,
            track_planting: true,
            planted_by: person
          )

          planting = BetterTogether::SeedPlanting.last
          expect(planting.status).to eq('completed')
          expect(planting.completed_at).to be_present
        end

        # rubocop:todo RSpec/MultipleExpectations
        it 'marks planting as failed on error' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
          # rubocop:enable RSpec/MultipleExpectations
          # Create invalid seed data
          invalid_data = valid_seed_data.deep_dup
          invalid_data['better_together']['seed'].delete('type')

          expect do
            described_class.plant_with_validation(
              invalid_data,
              track_planting: true,
              planted_by: person
            )
          end.to raise_error(ArgumentError)

          planting = BetterTogether::SeedPlanting.last
          expect(planting.status).to eq('failed')
          expect(planting.error_message).to be_present
          expect(planting.completed_at).to be_present # failed_at is stored in completed_at
        end

        it 'stores import options in planting metadata' do # rubocop:todo RSpec/ExampleLength
          described_class.plant_with_validation(
            valid_seed_data,
            track_planting: true,
            planted_by: person,
            custom_option: 'test_value'
          )

          planting = BetterTogether::SeedPlanting.last
          expect(planting.metadata['custom_option']).to eq('test_value')
        end
      end

      context 'without tracking' do # rubocop:todo RSpec/NestedGroups
        it 'does not create SeedPlanting record' do
          expect do
            described_class.plant_with_validation(valid_seed_data)
          end.not_to change(BetterTogether::SeedPlanting, :count)
        end
      end
    end

    describe '.find_person_for_planting' do
      it 'returns provided Person object' do
        result = described_class.find_person_for_planting(planted_by: person)
        expect(result).to eq(person)
      end

      it 'finds person by ID' do
        result = described_class.find_person_for_planting(planted_by_id: person.id)
        expect(result).to eq(person)
      end

      it 'returns nil when no person is provided' do
        result = described_class.find_person_for_planting({})
        expect(result).to be_nil
      end
    end

    describe 'planting helper methods' do
      let(:options) do
        {
          track_planting: true,
          planted_by: person,
          source: 'test',
          validate: true
        }
      end

      describe '.create_seed_planting' do # rubocop:todo RSpec/NestedGroups
        # rubocop:todo RSpec/MultipleExpectations
        it 'creates SeedPlanting with correct attributes' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
          # rubocop:enable RSpec/MultipleExpectations
          planting = described_class.create_seed_planting(options)

          expect(planting).to be_persisted
          expect(planting.planted_by).to eq(person)
          expect(planting.status).to eq('pending')
          expect(planting.metadata['source']).to eq('test')
          expect(planting.metadata['validate']).to be true
        end

        it 'returns nil when tracking disabled' do
          result = described_class.create_seed_planting(options.except(:track_planting))
          expect(result).to be_nil
        end

        it 'handles creation errors gracefully' do
          allow(BetterTogether::SeedPlanting).to receive(:create!).and_raise(StandardError.new('DB error'))

          result = described_class.create_seed_planting(options)
          expect(result).to be_nil
        end
      end

      describe '.update_seed_planting_success' do # rubocop:todo RSpec/NestedGroups
        let(:planting) { create(:better_together_seed_planting, creator: person) }
        let(:import_result) { { records_created: 5, records_updated: 2 } }

        it 'marks planting as completed' do # rubocop:todo RSpec/MultipleExpectations
          described_class.update_seed_planting_success(planting, import_result)

          planting.reload
          expect(planting.status).to eq('completed')
          expect(planting.completed_at).to be_present
          expect(planting.result['records_created']).to eq(5)
        end

        it 'handles nil planting gracefully' do
          expect do
            described_class.update_seed_planting_success(nil, import_result)
          end.not_to raise_error
        end
      end

      describe '.update_seed_planting_failure' do # rubocop:todo RSpec/NestedGroups
        let(:planting) { create(:better_together_seed_planting, creator: person) }
        let(:error) { StandardError.new('Import failed') }

        # rubocop:todo RSpec/MultipleExpectations
        it 'marks planting as failed' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
          # rubocop:enable RSpec/MultipleExpectations
          described_class.update_seed_planting_failure(planting, error)

          planting.reload
          expect(planting.status).to eq('failed')
          expect(planting.error_message).to eq('Import failed')
          expect(planting.completed_at).to be_present
          expect(planting.metadata['error_details']['error_class']).to eq('StandardError')
        end

        it 'handles nil planting gracefully' do
          expect do
            described_class.update_seed_planting_failure(nil, error)
          end.not_to raise_error
        end
      end
    end
  end
end
