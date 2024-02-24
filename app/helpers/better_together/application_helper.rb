# frozen_string_literal: true

module BetterTogether
  module ApplicationHelper
    def base_url
      ::BetterTogether.base_url
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

    def host_platform
      host_platform = BetterTogether::Platform.find_by(host: true)
      unless host_platform.present?
        return BetterTogether::Platform.new(name: 'Better Together Community Engine',
                                            url: base_url)
      end

      host_platform
    end

    def host_community
      host_community = BetterTogether::Community.find_by(host: true)
      return BetterTogether::Community.new(name: 'Better Together') unless host_community.exists?

      host_community
    end

    def host_setup_wizard
      host_setup_wizard = BetterTogether::Wizard.find_by(identifier: 'host_setup')
      unless host_setup_wizard.present?
        raise StandardError,
              'Host Setup Wizard not configured. Please generate it by running the seed task using rails db:seed'
      end

      host_setup_wizard
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

    def better_together_nav_items
      @better_together_nav_area ||= ::BetterTogether::NavigationArea.friendly.find('better-together')
      @better_together_nav_items ||= @better_together_nav_area&.navigation_items&.visible&.top_level&.ordered&.includes(:children) || []
    end

    def platform_header_admin_nav_items
      @platform_header_admin_nav_area ||= ::BetterTogether::NavigationArea.friendly.find('platform-header-admin')
      @platform_header_admin_nav_items ||= @platform_header_admin_nav_area&.navigation_items&.visible&.top_level&.ordered&.includes(:children) || []
    end

    def platform_footer_nav_items
      @platform_footer_nav_area ||= ::BetterTogether::NavigationArea.friendly.find('platform-footer')
      @platform_footer_nav_items ||= @platform_footer_nav_area&.navigation_items&.visible&.top_level&.ordered&.includes(:children) || []
    end

    def platform_header_nav_items
      @platform_header_nav_area ||= ::BetterTogether::NavigationArea.friendly.find('platform-header')
      @platform_header_nav_items ||= @platform_header_nav_area&.navigation_items&.visible&.top_level&.ordered&.includes(:children) || []
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
