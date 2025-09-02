# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Matchmaker finds offers or requests that align with a given record
    class Matchmaker
      # Returns the opposite type matches for a request or offer
      # - If given a Request -> returns matching Offers
      # - If given an Offer   -> returns matching Requests
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/CyclomaticComplexity
      def self.match(record) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        offer_klass   = BetterTogether::Joatu::Offer
        request_klass = BetterTogether::Joatu::Request
        rl_klass      = BetterTogether::Joatu::ResponseLink

        case record
        when request_klass
          candidates = offer_klass.status_open
          # Category overlap if any
          if record.category_ids.any?
            candidates = candidates.joins(:categories)
                                   .where(BetterTogether::Joatu::Category.table_name => { id: record.category_ids })
          end

          # Target type must align when present; target_id supports wildcard semantics
          candidates = candidates.where(target_type: record.target_type) if record.target_type.present?
          if record.target_id.present?
            candidates = candidates.where(
              "#{offer_klass.table_name}.target_id = ? OR #{offer_klass.table_name}.target_id IS NULL",
              record.target_id
            )
          end

          # Exclude same creator
          candidates = candidates.where.not(creator_id: record.creator_id)

          # Pair-specific ResponseLink exclusion (exclude if Request -> Offer link already exists for this pair)
          join_sql = ActiveRecord::Base.send(
            :sanitize_sql_array,
            [
              # rubocop:todo Layout/LineLength
              "LEFT JOIN #{rl_klass.table_name} AS rl ON rl.source_type = ? AND rl.source_id = ? AND rl.response_type = ? AND rl.response_id = #{offer_klass.table_name}.id",
              # rubocop:enable Layout/LineLength
              request_klass.name, record.id, offer_klass.name
            ]
          )
          candidates = candidates.joins(join_sql).where('rl.id IS NULL')

          candidates.distinct
        when offer_klass
          candidates = request_klass.status_open
          if record.category_ids.any?
            candidates = candidates.joins(:categories)
                                   .where(BetterTogether::Joatu::Category.table_name => { id: record.category_ids })
          end

          candidates = candidates.where(target_type: record.target_type) if record.target_type.present?
          if record.target_id.present?
            candidates = candidates.where(
              "#{request_klass.table_name}.target_id = ? OR #{request_klass.table_name}.target_id IS NULL",
              record.target_id
            )
          end

          candidates = candidates.where.not(creator_id: record.creator_id)

          # Pair-specific ResponseLink exclusion (exclude if Offer -> Request link already exists for this pair)
          join_sql = ActiveRecord::Base.send(
            :sanitize_sql_array,
            [
              # rubocop:todo Layout/LineLength
              "LEFT JOIN #{rl_klass.table_name} AS rl ON rl.source_type = ? AND rl.source_id = ? AND rl.response_type = ? AND rl.response_id = #{request_klass.table_name}.id",
              # rubocop:enable Layout/LineLength
              offer_klass.name, record.id, request_klass.name
            ]
          )
          candidates = candidates.joins(join_sql).where('rl.id IS NULL')

          candidates.distinct
        else
          raise ArgumentError, "Unsupported record type: #{record.class.name}"
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/MethodLength
    end
  end
end
