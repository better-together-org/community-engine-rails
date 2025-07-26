# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/geography/map',
          class: 'BetterTogether::Geography::Map',
          aliases: %i[geography_map] do
    name { 'test' }
  end
end
