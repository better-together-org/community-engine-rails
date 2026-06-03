# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::Ingest do
  it 'imports a canonical seed and returns payload metadata' do
    seed_data = {
      'better_together' => {
        version: '1.0',
        seed: {
          type: 'BetterTogether::Seed',
          identifier: "seed-post-#{SecureRandom.hex(4)}",
          created_by: 'FederatedExport',
          created_at: Time.current.utc.iso8601,
          description: 'Remote post seed',
          origin: { lane: 'platform_shared', profile: 'platform_shared', content_type: 'post' }
        },
        payload: {
          type: 'post',
          id: SecureRandom.uuid,
          attributes: { title: 'Remote Post' }
        }
      }
    }

    result = described_class.call(seed_data: seed_data)

    expect(result.seed_record).to be_a(BetterTogether::Seed)
    expect(result.payload[:type]).to eq('post')
    expect(result.imported_record).to be_nil
  end

  it 'yields to a supplied record importer when provided' do
    seed_data = {
      'better_together' => {
        version: '1.0',
        seed: {
          type: 'BetterTogether::Seed',
          identifier: "seed-page-#{SecureRandom.hex(4)}",
          created_by: 'FederatedExport',
          created_at: Time.current.utc.iso8601,
          description: 'Remote page seed',
          origin: { lane: 'platform_shared', profile: 'platform_shared', content_type: 'page' }
        },
        payload: {
          type: 'page',
          id: 'legacy-page-42',
          attributes: { title: 'Remote Page' }
        }
      }
    }

    importer = lambda do |seed:, payload:, connection:|
      [seed.identifier, payload[:type], connection]
    end

    result = described_class.call(seed_data: seed_data, record_importer: importer)

    expect(result.imported_record).to eq([result.seed_record.identifier, 'page', nil])
  end
end
