# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/joatu/agreement', class: 'BetterTogether::Joatu::Agreement',
                                             aliases: %i[better_together_joatu_agreement joatu_agreement] do
    id { SecureRandom.uuid }
    offer
    request
    terms { 'Standard terms' }
    value { '10 tokens' }
  end
end
