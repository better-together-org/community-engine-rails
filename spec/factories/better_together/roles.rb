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
      resource_class { Role::RESOURCE_CLASSES.sample }
    end
  end
end
