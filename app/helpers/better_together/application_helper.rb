module BetterTogether
  module ApplicationHelper

    def base_url
      request.protocol + request.host_with_port
    end
    
    def current_identity
      return unless user_signed_in?
      return unless current_user.person
      # TODO: Modify to support when "Active identity" becomes a feature
      current_user.person
    end

    # Can search for named routes directly in the main app, omitting
    # the "better_together." prefix
    def method_missing method, *args, &block
      if better_together_url_helper?(method)
        better_together.send(method, *args)
      else
        super
      end
    end

    def respond_to?(method)
      better_together_url_helper?(method) or super
    end

    private

    def better_together_url_helper?(method)
      (method.to_s.end_with?('_path') or method.to_s.end_with?('_url')) and
        better_together.respond_to?(method)
    end
  end
end
