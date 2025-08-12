# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::HostDashboardController, type: :controller do
  describe '#build_resources' do
    it 'returns hashes with collection, count, and url helper' do
      create_list(:community, 4)

      result = controller.send(:build_resources, [[BetterTogether::Community, :community_path]])
      resource = result.first

      expect(resource[:collection]).to eq(BetterTogether::Community.order(created_at: :desc).limit(3))
      expect(resource[:count]).to eq(BetterTogether::Community.count)
      expect(resource[:url_helper]).to eq(:community_path)
    end
  end
end
