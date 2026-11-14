# frozen_string_literal: true

module BetterTogether
  module Mcp
    # MCP Tool to search people by name or handle
    # Respects privacy settings and block lists
    class SearchPeopleTool < ApplicationTool
      description 'Search people by name or handle, respecting privacy settings and block lists'
      tags :public

      arguments do
        required(:query)
          .filled(:string)
          .description('Search query to match against person names and identifiers')
        optional(:limit)
          .filled(:integer)
          .description('Maximum number of results to return (default: 20)')
      end

      # Search people with authorization and privacy filtering
      # @param query [String] The search query
      # @param limit [Integer] Maximum results (default: 20)
      # @return [String] JSON array of person objects
      def call(query:, limit: 20)
        with_timezone_scope do
          people = search_people(query, limit)
          result = JSON.generate(people.map { |person| serialize_person(person) })

          log_invocation('search_people', { query: query, limit: limit }, result.bytesize)
          result
        end
      end

      private

      def search_people(query, limit)
        pattern = "%#{sanitize_like(query)}%"
        base = policy_scope(BetterTogether::Person)

        # Match names through a subquery rather than joining the translations table: the policy
        # scope already eager-loads translations, and a join filtered to key = 'name' would leave
        # each person's loaded translations without their slug, so person_path would fail.
        name_matches = Mobility::Backends::ActiveRecord::KeyValue::StringTranslation
                       .where(translatable_type: BetterTogether::Person.polymorphic_name, key: 'name')
                       .where('value ILIKE ?', pattern)
                       .select(:translatable_id)

        base.where(id: name_matches)
            .or(base.where('identifier ILIKE ?', pattern))
            .distinct
            .limit([limit, 100].min)
      end

      def serialize_person(person)
        person_attributes(person).merge(person_metadata(person))
      end

      def person_attributes(person)
        {
          id: person.id,
          name: person.name,
          handle: person.identifier,
          locale: person.locale,
          privacy: person.privacy
        }
      end

      def person_metadata(person)
        {
          url: BetterTogether::Engine.routes.url_helpers.person_path(person, locale: I18n.locale)
        }
      end
    end
  end
end
