# frozen_string_literal: true

require 'rails_helper'

# Guards against re-introducing an automatic GeographyBuilder call in db/seeds.rb — that bulk-creates
# ~230+ records, each of which enqueues a live-Nominatim GeocodingJob (see geocodes_self on
# Continent/Country/State/Region/Settlement), which would fire an unthrottled burst of external
# HTTP calls on every seed/deploy run. Geography reference-data install is deliberately admin-only
# now (better_together:geography:seed_reference_data rake task; a seed-catalog UI is a follow-up).
RSpec.describe 'db/seeds.rb' do # rubocop:todo RSpec/DescribeClass
  let(:seeds_source) { BetterTogether::Engine.root.join('db/seeds.rb').read }

  it 'does not automatically invoke GeographyBuilder' do
    expect(seeds_source).not_to include('BetterTogether::GeographyBuilder')
  end
end
