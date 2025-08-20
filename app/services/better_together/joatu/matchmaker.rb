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
      def self.match(record) # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
        case record
        when BetterTogether::Joatu::Request
  offers = BetterTogether::Joatu::Offer.status_open # rubocop:todo Layout/IndentationWidth
  if record.category_ids.any?
    offers = offers.joins(:categories)
                   .where(BetterTogether::Joatu::Category.table_name => { id: record.category_ids })
  end

  offers = offers.where(target_type: record.target_type)
  offers = offers.where(target_id: record.target_id) if record.target_id.present?
  offers = offers.where(target_id: nil) if record.target_id.blank?

  # Exclude offers that already have direct response links (they've been responded to)
  # rubocop:todo Layout/LineLength
  offers = offers.left_joins(:response_links_as_source).where(BetterTogether::Joatu::ResponseLink.table_name => { id: nil })
  # rubocop:enable Layout/LineLength

  offers.where.not(creator_id: record.creator_id).distinct
        when BetterTogether::Joatu::Offer
  requests = BetterTogether::Joatu::Request.status_open # rubocop:todo Layout/IndentationWidth
  if record.category_ids.any?
    requests = requests.joins(:categories)
                       .where(BetterTogether::Joatu::Category.table_name => { id: record.category_ids })
  end

  requests = requests.where(target_type: record.target_type)
  requests = requests.where(target_id: record.target_id) if record.target_id.present?
  requests = requests.where(target_id: nil) if record.target_id.blank?

  # Exclude requests that already have direct response links (they've been responded to)
  # rubocop:todo Layout/LineLength
  requests = requests.left_joins(:response_links_as_source).where(BetterTogether::Joatu::ResponseLink.table_name => { id: nil })
  # rubocop:enable Layout/LineLength

  requests.where.not(creator_id: record.creator_id).distinct
        else
  raise ArgumentError, "Unsupported record type: #{record.class.name}" # rubocop:todo Layout/IndentationWidth
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/MethodLength
    end
  end
end
