require 'faker'

module BetterTogether
  FactoryBot.define do
    factory :better_together_role, class: Role do
      bt_id { "MyString" }
      reserved { false }
      sort_order { 1 }
      target_class { "MyString" }
    end
  end
end
