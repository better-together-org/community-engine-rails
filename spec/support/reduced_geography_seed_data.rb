# frozen_string_literal: true

# The geography seed specs exercise ordering, prerequisites and idempotency, not the contents of
# the dataset, but seeding all ~196 countries (each with a space, community, translations and
# slugs) costs 35-60 s per example. Tag a group :reduced_geography to seed a small country
# subset instead; tag one example :full_geography to keep proving the real dataset seeds.
RSpec.configure do |config|
  config.before(:each, :reduced_geography) do |example|
    next if example.metadata[:full_geography]

    subset = BetterTogether::GeographyBuilder.send(:countries).select do |country|
      %w[Canada Algeria Brazil].include?(country[:name])
    end
    allow(BetterTogether::GeographyBuilder).to receive(:countries).and_return(subset)
  end
end
