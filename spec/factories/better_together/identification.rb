
module BetterTogether
    FactoryBot.define do
    factory :identification, class: Identification do
      bt_id { Faker::Internet.uuid }
      active { true }
      identity factory: :person
      agent factory: :person #should not actually be person, but a devise or oAuth backed model
    end
  end
end
