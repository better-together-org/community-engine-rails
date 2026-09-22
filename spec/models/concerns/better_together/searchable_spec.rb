# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Searchable do
  describe 'pg_search interface normalization' do
    it 'exposes translated search associations for every supported searchable model', :aggregate_failures do
      expectations = {
        BetterTogether::Post => {
          string_translations: [:value],
          rich_text_translations: [:body]
        },
        BetterTogether::Event => {
          string_translations: [:value],
          rich_text_translations: [:body]
        },
        BetterTogether::Community => {
          string_translations: [:value],
          text_translations: [:value],
          rich_text_translations: [:body]
        },
        BetterTogether::Checklist => {
          string_translations: [:value]
        },
        BetterTogether::CallForInterest => {
          string_translations: [:value],
          rich_text_translations: [:body]
        },
        BetterTogether::Joatu::Offer => {
          string_translations: [:value],
          rich_text_translations: [:body]
        },
        BetterTogether::Joatu::Request => {
          string_translations: [:value],
          rich_text_translations: [:body]
        }
      }

      expectations.each do |model, expected_associations|
        expect(model.search_pg_search_options.fetch(:associated_against)).to include(expected_associations)
      end
    end

    it 'keeps page search adapter-compatible through the database-backed fallback' do
      expect(BetterTogether::Page.pg_search_enabled?).to be(false)
      expect(BetterTogether::Page.search_pg_search_options).to be_nil
    end
  end
end
