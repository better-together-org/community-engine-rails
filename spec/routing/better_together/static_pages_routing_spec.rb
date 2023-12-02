require "rails_helper"

RSpec.describe BetterTogether::StaticPagesController, type: :routing do
  describe "routing" do
    it "routes to #community_engine" do
      expect(:get => "/bt").to route_to("better_together/pages#show", path: 'bt' )
    end
  end
end
