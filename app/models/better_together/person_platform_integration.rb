class BetterTogether::PersonPlatformIntegration < ApplicationRecord
  belongs_to :person
  belongs_to :platform
end
