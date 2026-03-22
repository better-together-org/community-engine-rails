# frozen_string_literal: true

require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the Metrics::ReportsHelper. For example:
#
# describe Metrics::ReportsHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
module BetterTogether
  RSpec.describe Metrics::ReportsHelper do
    it 'includes search health tab styles' do
      expect(helper.metrics_tab_styles).to include(:searchhealth)
      expect(helper.metrics_tab_styles[:searchhealth]).to include(:icon, :accent)
    end
  end
end
