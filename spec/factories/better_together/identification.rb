
module BetterTogether
    FactoryBot.define do
    factory :identification, class: Identification do
      bt_id { Faker::Internet.uuid }
      active { false }
      identity factory: :person
      agent factory: :user #should not actually be person, but a devise or oAuth backed model
    end
  end
end
