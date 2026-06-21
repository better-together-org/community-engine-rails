# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonAssociationAudit do
  it 'covers every discovered person and user reference in the manifest' do
    result = described_class.call

    expect(result[:missing_manifest_entries]).to eq([])
    expect(result[:stale_manifest_entries]).to eq([])
    expect(result[:missing_reverse_associations]).to eq([])
  end
end
