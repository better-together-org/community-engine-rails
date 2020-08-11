require "rails_helper"

RSpec.describe BetterTogether::StaticPagesController, type: :routing do
  describe "routing" do
    it "routes to #home" do
      expect(:get => "/bt").to route_to("better_together/static_pages#home")
    end
  end
end
