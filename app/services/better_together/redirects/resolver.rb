# frozen_string_literal: true

module BetterTogether
  module Redirects
    # Finds the active redirect for a platform and request path.
    # The platform's active rows are cached as one small hash; a platform with
    # more than MAX_CACHED rows falls back to an indexed query per request.
    class Resolver
      MAX_CACHED = 10_000
      Result = Struct.new(:id, :to_path, :status, :preserve_query, keyword_init: true)

      def self.call(platform_id:, path:)
        new(platform_id, path).call
      end

      def initialize(platform_id, path)
        @platform_id = platform_id
        @key = Redirect.normalize_path(path).downcase
      end

      def call
        return if @platform_id.blank?

        map = cached_map
        return lookup_in_db if map.nil?

        row = map[@key]
        row && Result.new(**row)
      end

      private

      def cached_map
        Rails.cache.fetch(Redirect.cache_key_for(@platform_id), expires_in: 5.minutes) do
          scope = Redirect.active.where(platform_id: @platform_id)
          next false if scope.limit(MAX_CACHED + 1).count > MAX_CACHED

          scope.pluck(:id, :from_path, :to_path, :status, :preserve_query).to_h do |id, from, to, status, preserve|
            [from.downcase, { id:, to_path: to, status:, preserve_query: preserve }]
          end
        end || nil
      end

      def lookup_in_db
        row = Redirect.active.where(platform_id: @platform_id).find_by(Redirect.arel_table[:from_path].lower.eq(@key))
        row && Result.new(id: row.id, to_path: row.to_path, status: row.status, preserve_query: row.preserve_query)
      end
    end
  end
end
