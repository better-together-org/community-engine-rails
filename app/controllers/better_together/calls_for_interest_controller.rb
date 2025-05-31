module BetterTogether
  class CallsForInterestController < FriendlyResourceController

    def index
      @draft_calls_for_interest = @calls_for_interest.draft
      @upcoming_calls_for_interest = @calls_for_interest.upcoming
      @past_calls_for_interest = @calls_for_interest.past
    end

    protected

    def resource_class
      BetterTogether::CallForInterest
    end
  end
end
