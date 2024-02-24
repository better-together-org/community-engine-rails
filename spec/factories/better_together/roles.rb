require 'faker'

module BetterTogether
  FactoryBot.define do
    factory(
      :better_together_role,
      class: Role,
      aliases: %i[role]
    ) do
      bt_id { Faker::Internet.uuid }
      reserved { false }
      name { Faker::Name.name }
    end
  end
end
