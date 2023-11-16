module BetterTogether
  module ApplicationHelper

    def base_url
      request.protocol + request.host_with_port
    end
    
    def current_identity
      # TODO: Modify to support when "Active identity" becomes a feature
      current_person
    end
    
    def current_person
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

    def host_platform
      host_platform = BetterTogether::Platform.find_by(host: true)
      return BetterTogether::Platform.new(name: 'Better Together Community Engine', url: base_url) unless host_platform.present?

      host_platform
    end

    def host_community
      host_community = BetterTogether::Community.find_by(host: true)
      return BetterTogether::Community.new(name: 'Better Together') unless host_community.exists?

      host_community
    end

    private

    def better_together_url_helper?(method)
      (method.to_s.end_with?('_path') or method.to_s.end_with?('_url')) and
        better_together.respond_to?(method)
    end
  end
end
