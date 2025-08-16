# frozen_string_literal: true

module BetterTogether
  # CRUD for CallForInterest
  class CallsForInterestController < FriendlyResourceController
    def index
      @draft_calls_for_interest = @call_for_interests.draft
      @upcoming_calls_for_interest = @call_for_interests.upcoming
      @past_calls_for_interest = @call_for_interests.past
    end

    protected

    def resource_class
      BetterTogether::CallForInterest
    end
  end
end
