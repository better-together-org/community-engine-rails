# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seed do
  describe '.import_or_update!' do
    let(:seed_data) do
      {
        'better_together' => {
          version: '1.0',
          seed: {
            type: 'BetterTogether::Seed',
            identifier: 'seed-post-abc123',
            created_by: 'FederatedExport',
            created_at: Time.current.utc.iso8601,
            description: 'Federated seed',
            origin: { lane: 'platform_shared', content_type: 'post' }
          },
          payload: {
            type: 'post',
            id: SecureRandom.uuid,
            attributes: { title: 'Remote Post' }
          }
        }
      }
    end

    it 'persists and updates a deterministic seed envelope' do
      seed = described_class.import_or_update!(seed_data)
      expect(seed.payload_data[:type]).to eq('post')
      expect(seed.platform_shared?).to be(true)

      updated = seed_data.deep_dup
      updated['better_together'][:payload][:attributes][:title] = 'Updated Title'
      updated_seed = described_class.import_or_update!(updated)

      expect(updated_seed.id).to eq(seed.id)
      expect(updated_seed.payload_data[:attributes][:title]).to eq('Updated Title')
    end
  end
end
