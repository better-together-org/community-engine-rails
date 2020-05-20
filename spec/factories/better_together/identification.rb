
module BetterTogether
  module Community
    FactoryBot.define do
      factory :identification, class: Identification do
        active { true }
        identity factory: :person
        agent factory: :person #should not actually be person, but a devise or oAuth backed model
      end
    end
  end
end
