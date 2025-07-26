# frozen_string_literal: true

require 'faker'

module BetterTogether
  FactoryBot.define do
    factory(
      'better_together/role',
      class: 'BetterTogether::Role',
      aliases: %i[role better_together_role]
    ) do
      id { Faker::Internet.uuid }
      protected { false }
      name { Faker::Name.name }
      resource_type { Role::RESOURCE_CLASSES.sample }
    end
  end
end
