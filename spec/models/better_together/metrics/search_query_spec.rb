# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::SearchQuery do
  subject(:search_query) do
    described_class.new(
      query: 'community events',
      results_count: 3,
      locale: 'en',
      searched_at: Time.current,
      logged_in: false
    )
  end

  describe 'validations' do
    it 'is valid with required attributes' do
      expect(search_query).to be_valid
    end

    it 'requires query' do
      search_query.query = nil
      expect(search_query).not_to be_valid
    end

    it 'requires results_count' do
      search_query.results_count = nil
      expect(search_query).not_to be_valid
    end

    it 'requires results_count to be non-negative' do
      search_query.results_count = -1
      expect(search_query).not_to be_valid
    end

    it 'allows results_count of zero' do
      search_query.results_count = 0
      expect(search_query).to be_valid
    end

    it 'requires locale' do
      search_query.locale = nil
      expect(search_query).not_to be_valid
    end

    it 'rejects unknown locale' do
      search_query.locale = 'zz'
      expect(search_query).not_to be_valid
    end

    it 'requires searched_at' do
      search_query.searched_at = nil
      expect(search_query).not_to be_valid
    end

    it 'requires logged_in to be boolean' do
      search_query.logged_in = nil
      expect(search_query).not_to be_valid
    end
  end
end
