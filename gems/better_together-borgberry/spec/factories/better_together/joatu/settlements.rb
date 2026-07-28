# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/joatu/settlement', class: 'BetterTogether::Joatu::Settlement',
                                              aliases: %i[better_together_joatu_settlement joatu_settlement] do
    id { SecureRandom.uuid }
    agreement { association :better_together_joatu_agreement }
    payer { association :better_together_person }
    recipient { association :better_together_person }
    c3_millitokens { 0 }
    status { 'pending' }
  end
end
