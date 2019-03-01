require 'faker'

module BetterTogether::Core
  FactoryBot.define do
    factory :better_together_core_role, class: Role do
      bt_id { "MyString" }
      reserved { false }
      sort_order { 1 }
      target_class { "MyString" }
    end
  end
end
