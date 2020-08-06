require 'faker'

module BetterTogether
  FactoryBot.define do
    factory :better_together_role, class: Role do
      bt_id { Faker::Internet.uuid }
      reserved { false }
      sort_order { 1 }
      target_class { "MyString" }
    end
  end
end
