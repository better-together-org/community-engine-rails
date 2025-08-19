# frozen_string_literal: true

module BetterTogether
  module Joatu
    class ResponseLinksController < JoatuController
      before_action :authenticate_user!

      def create
        # Create a request from offer or offer from request, linking them via ResponseLink
        source_type = params[:source_type]
        source_id = params[:source_id]

        unless %w[BetterTogether::Joatu::Offer BetterTogether::Joatu::Request].include?(source_type)
          return redirect_back fallback_location: joatu_root_path, alert: 'Invalid source'
        end

        source = source_type.constantize.find_by(id: source_id)
        return redirect_back fallback_location: joatu_root_path, alert: 'Source not found' unless source

        if source.is_a?(BetterTogether::Joatu::Offer)
          # Build a new Request from offer details
          request = BetterTogether::Joatu::Request.new
          request.name = source.name
          request.description = source.description
          request.creator_id = helpers.current_person&.id
          request.target_type = source.target_type if source.respond_to?(:target_type)
          request.target_id = source.target_id if source.respond_to?(:target_id)
          request.urgency = source.urgency if source.respond_to?(:urgency)
          request.address_id = source.address_id if source.respond_to?(:address_id)
          request.category_ids = source.categories.pluck(:id) if source.respond_to?(:categories)

          if request.save
            ResponseLink.create!(source: source, response: request, creator_id: helpers.current_person&.id)
            redirect_to joatu_request_path(request), notice: 'Request created in response to offer.'
          else
            redirect_back fallback_location: joatu_offer_path(source), alert: request.errors.full_messages.to_sentence
          end
        elsif source.is_a?(BetterTogether::Joatu::Request)
          offer = BetterTogether::Joatu::Offer.new
          offer.name = source.name
          offer.description = source.description
          offer.creator_id = helpers.current_person&.id
          offer.target_type = source.target_type if source.respond_to?(:target_type)
          offer.target_id = source.target_id if source.respond_to?(:target_id)
          offer.urgency = source.urgency if source.respond_to?(:urgency)
          offer.address_id = source.address_id if source.respond_to?(:address_id)
          offer.category_ids = source.categories.pluck(:id) if source.respond_to?(:categories)

          if offer.save
            ResponseLink.create!(source: source, response: offer, creator_id: helpers.current_person&.id)
            redirect_to joatu_offer_path(offer), notice: 'Offer created in response to request.'
          else
            redirect_back fallback_location: joatu_request_path(source), alert: offer.errors.full_messages.to_sentence
          end
        else
          redirect_back fallback_location: joatu_root_path, alert: 'Unsupported source type'
        end
      end
    end
  end
end
