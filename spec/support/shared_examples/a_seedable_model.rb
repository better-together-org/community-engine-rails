# frozen_string_literal: true

RSpec.shared_examples 'a seedable model' do
  it 'includes the Seedable concern' do
    expect(described_class.ancestors).to include(BetterTogether::Seedable)
  end

  describe 'Seedable instance methods' do
    # Use create(...) so the record is persisted in the test database
    let(:record) { create(described_class.name.underscore.to_sym) }

    it 'responds to #plant' do
      expect(record).to respond_to(:plant)
    end

    it 'responds to #export_as_seed' do
      expect(record).to respond_to(:export_as_seed)
    end

    it 'responds to #export_as_seed_yaml' do
      expect(record).to respond_to(:export_as_seed_yaml)
    end

    describe '#export_as_seed' do
      it 'returns a hash with the default root key' do
        seed_hash = record.export_as_seed
        expect(seed_hash.keys).to include(BetterTogether::Seed::DEFAULT_ROOT_KEY)
      end

      it 'includes the record data under :record (or your chosen key)' do
        seed_hash = record.export_as_seed
        root_key = seed_hash.keys.first
        expect(seed_hash[root_key]).to have_key(:record)
      end
    end

    describe '#export_as_seed_yaml' do
      it 'returns a valid YAML string' do # rubocop:todo RSpec/MultipleExpectations
        yaml_str = record.export_as_seed_yaml
        expect(yaml_str).to be_a(String)
        expect(yaml_str).to include(BetterTogether::Seed::DEFAULT_ROOT_KEY.to_s)
      end
    end
  end

  describe 'Seedable class methods' do
    let(:records) { build_list(described_class.name.underscore.to_sym, 3) }

    it 'responds to .export_collection_as_seed' do
      expect(described_class).to respond_to(:export_collection_as_seed)
    end

    it 'responds to .export_collection_as_seed_yaml' do
      expect(described_class).to respond_to(:export_collection_as_seed_yaml)
    end

    describe '.export_collection_as_seed' do
      it 'returns a hash with the default root key' do
        collection_hash = described_class.export_collection_as_seed(records)
        expect(collection_hash.keys).to include(BetterTogether::Seed::DEFAULT_ROOT_KEY)
      end

      it 'includes an array of records under :records' do # rubocop:todo RSpec/MultipleExpectations
        collection_hash = described_class.export_collection_as_seed(records)
        root_key = collection_hash.keys.first
        expect(collection_hash[root_key]).to have_key(:records)
        expect(collection_hash[root_key][:records]).to be_an(Array)
        expect(collection_hash[root_key][:records].size).to eq(records.size)
      end
    end

    describe '.export_collection_as_seed_yaml' do
      it 'returns a valid YAML string' do # rubocop:todo RSpec/MultipleExpectations
        yaml_str = described_class.export_collection_as_seed_yaml(records)
        expect(yaml_str).to be_a(String)
        expect(yaml_str).to include(BetterTogether::Seed::DEFAULT_ROOT_KEY.to_s)
      end
    end
  end
end
