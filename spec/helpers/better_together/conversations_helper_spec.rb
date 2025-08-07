# frozen_string_literal: true

require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the ConversationsHelper. For example:
#
# describe ConversationsHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
module BetterTogether
  RSpec.describe ConversationsHelper, type: :helper do
    it 'exists' do
      expect(described_class).to be
    end
  end
end
