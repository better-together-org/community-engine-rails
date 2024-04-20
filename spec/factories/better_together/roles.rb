# frozen_string_literal: true

require 'faker'

module BetterTogether
  FactoryBot.define do
    factory(
      :better_together_role,
      class: Role,
      aliases: %i[role]
    ) do
      id { Faker::Internet.uuid }
      protected { false }
      name { Faker::Name.name }
      target_class { Role::TARGET_CLASSES.sample }
    end
  end
end
