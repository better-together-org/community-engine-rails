# frozen_string_literal: true

module BetterTogether
  # Lets an index be embedded in a page as a lazy turbo-frame (a community page tab) and be scoped to one
  # community with ?community_id=<slug or id>. `index_frame_id` is the id of the frame the request came from
  # (nil for a normal page), so the view can wrap itself in that frame, lay out for a narrow pane and keep its
  # filters inside the frame. `scoped_community` is nil when no community was asked for or it does not exist.
  module FramedIndex
    extend ActiveSupport::Concern

    FRAME_ID = /\A[\w-]+\z/

    included do
      helper_method :index_frame_id, :scoped_community
    end

    private

    def index_frame_id
      id = request.headers['Turbo-Frame'].to_s
      id if id.match?(FRAME_ID)
    end

    def scoped_community
      return @scoped_community if defined?(@scoped_community)

      return @scoped_community = nil if params[:community_id].blank?

      @scoped_community = BetterTogether::Community.friendly.find(params[:community_id].to_s)
    rescue ActiveRecord::RecordNotFound
      @scoped_community = nil
    end
  end
end
