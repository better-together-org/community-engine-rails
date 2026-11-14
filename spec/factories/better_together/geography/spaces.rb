# frozen_string_literal: true

FactoryBot.define do
  factory :geography_space, class: 'BetterTogether::Geography::Space',
                            aliases: %i[better_together_geography_space] do
    latitude { 47.5615 }
    longitude { -52.7126 }
    elevation { nil }
  end
end
