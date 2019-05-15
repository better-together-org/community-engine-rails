require 'faker'

module BetterTogether::Community
  FactoryBot.define do
    factory :better_together_community_role, class: Role do
      bt_id { "MyString" }
      reserved { false }
      sort_order { 1 }
      target_class { "MyString" }
    end
  end
end
