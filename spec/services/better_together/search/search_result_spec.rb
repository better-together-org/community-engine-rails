# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Search::SearchResult, type: :service do
  it 'holds all search response fields' do
    result = described_class.new([1, 2], ['suggestion'], :ok, :database, nil)
    expect(result.records).to eq([1, 2])
    expect(result.suggestions).to eq(['suggestion'])
    expect(result.status).to eq(:ok)
    expect(result.backend).to eq(:database)
    expect(result.error).to be_nil
  end

  it 'defaults all fields to nil when constructed without arguments' do
    result = described_class.new
    expect(result.records).to be_nil
    expect(result.status).to be_nil
    expect(result.error).to be_nil
  end

  it 'stores an error object' do
    error = StandardError.new('search failed')
    result = described_class.new([], [], :error, :pg_search, error)
    expect(result.error).to eq(error)
  end

  it 'has the expected Struct members' do
    expect(described_class.members).to eq(%i[records suggestions status backend error])
  end
end
