# frozen_string_literal: true

require 'rails_helper'
require 'geocoder/results/nominatim' # Geocoder lazy-loads this — force it so instance_double sees the class

RSpec.describe BetterTogether::Geography::SeedCoordinatesGenerator do
  # Stubs the real committed packet path with a scratch file for the duration of each example —
  # this spec must never read or overwrite the actual lib/better_together/geography/
  # seed_coordinates.yml that ships with the gem.
  let(:packet_path) { Rails.root.join('tmp', "seed_coordinates_spec_#{SecureRandom.hex(4)}.yml") }

  before do
    stub_const('BetterTogether::Geography::SeedCoordinatesGenerator::PACKET_PATH', packet_path)
    allow_any_instance_of(described_class).to receive(:sleep) # rubocop:todo RSpec/AnyInstance
  end

  after { FileUtils.rm_f(packet_path) }

  def stub_geocoder_result(latitude, longitude)
    result = instance_double(Geocoder::Result::Nominatim, latitude:, longitude:)
    allow(Geocoder).to receive(:search).and_return([result])
  end

  describe '.call' do
    it 'writes a packet keyed by identifier under all five categories' do
      stub_geocoder_result(1.0, 2.0)

      described_class.call

      packet = YAML.safe_load_file(packet_path)
      expect(packet.keys).to contain_exactly('continents', 'countries', 'provinces', 'regions', 'settlements')

      first_continent_identifier = BetterTogether::GeographyBuilder.send(:continents).first[:name].parameterize
      expect(packet['continents'][first_continent_identifier]).to eq('latitude' => 1.0, 'longitude' => 2.0)
    end

    it 'temporarily overrides the lookup to :nominatim and restores the previous value after' do
      previous = Geocoder.config.lookup
      stub_geocoder_result(1.0, 2.0)

      described_class.call

      expect(Geocoder.config.lookup).to eq(previous)
    end

    it 'skips an entry without error when Geocoder returns no result' do
      allow(Geocoder).to receive(:search).and_return([])

      expect { described_class.call }.not_to raise_error

      packet = YAML.safe_load_file(packet_path)
      expect(packet['continents']).to be_empty
    end

    it 'skips already-present identifiers on a second call unless forced' do
      stub_geocoder_result(1.0, 2.0)
      described_class.call

      expect(Geocoder).not_to receive(:search)
      expect { described_class.call }.not_to raise_error
    end

    it 're-geocodes every entry when force: true is passed' do
      stub_geocoder_result(1.0, 2.0)
      described_class.call

      stub_geocoder_result(9.0, 9.0)
      described_class.call(force: true)

      packet = YAML.safe_load_file(packet_path)
      first_continent_identifier = BetterTogether::GeographyBuilder.send(:continents).first[:name].parameterize
      expect(packet['continents'][first_continent_identifier]).to eq('latitude' => 9.0, 'longitude' => 9.0)
    end

    it 'disambiguates provinces/settlements with a Canada suffix, unlike continents/countries' do
      received_queries = []
      allow(Geocoder).to receive(:search) do |query|
        received_queries << query
        [instance_double(Geocoder::Result::Nominatim, latitude: 1.0, longitude: 2.0)]
      end

      described_class.call

      expect(received_queries).to include('Canada')
      expect(received_queries).to include(a_string_ending_with(', Canada'))
      expect(received_queries).to include('Africa')
    end
  end
end
