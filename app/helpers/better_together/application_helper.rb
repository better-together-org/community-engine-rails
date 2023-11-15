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

    def set_host_platform_in_session(platform)
      session[:host_platform_id] = platform.id
    end

    def set_host_community_in_session(community)
      session[:host_community_id] = community.id if community
    end

    def host_platform
      return BetterTogether::Platform.find_by(bt_id: session[:host_platform_id]) if session[:host_platform_id].present?
      host_platform = BetterTogether::Platform.find_by(host: true)
      return BetterTogether::Platform.new(name: 'Better Together', url: base_url) unless host_platform.present?

      set_host_platform_in_session(host_platform)
      host_platform
    end

    def host_community
      return BetterTogether::Community.find_by(bt_id: session[:host_community_id]) if session[:host_community_id].present?
      host_community = host_platform ? host_platform.community : BetterTogether::Community.find_by(host: true)
      return nil unless host_community.exists?

      set_host_community_in_session(host_community)
      host_community
    end

    private

    def better_together_url_helper?(method)
      (method.to_s.end_with?('_path') or method.to_s.end_with?('_url')) and
        better_together.respond_to?(method)
    end
  end
end
