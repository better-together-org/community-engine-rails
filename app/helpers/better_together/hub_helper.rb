# frozen_string_literal: true

module BetterTogether
  # Helper methods used for displaying the Community Hub
  module HubHelper
    def activities
      BetterTogether::ActivityPolicy::Scope.new(current_user, PublicActivity::Activity).resolve
    end

    # Check if a trackable object is visible to the current user
    # @param trackable [ApplicationRecord] the trackable object (Page, Post, Event, etc.)
    # @return [Boolean] true if the trackable is visible to the current user
    def trackable_visible?(trackable)
      return false unless trackable

      # Delegate to the trackable's visibility API
      trackable.trackable_visible_in_activity_feed?(current_user)
    rescue NoMethodError
      # If trackable doesn't implement the API, use policy fallback
      policy_class = "#{trackable.class.name}Policy".constantize
      policy_class.new(current_user, trackable).show?
    rescue NameError
      # If no policy exists, default to visible (graceful degradation)
      true
    end

    # For generating time tags calculated using jquery.timeago
    def timeago(time, options = {})
      options[:class] ||= 'timeago'
      content_tag(:abbr, time.to_s, options.merge(title: time.getutc.iso8601)) if time
    end

    # Shortcut for outputing proper ownership of objects,
    # depending on who is looking
    # rubocop:todo Naming/PredicateMethod
    def whose?(user, object) # rubocop:todo Metrics/MethodLength, Naming/PredicateMethod
      # rubocop:enable Naming/PredicateMethod
      owner = case object
              when Page
                object.creator
              end
      if user && owner
        if user.id == owner.id
          'his'
        else
          "#{owner.nickname}'s"
        end
      else
        ''
      end
    end

    # Check if object still exists in the database and display a link to it,
    # otherwise display a proper message about it.
    # This is used in activities that can refer to
    # objects which no longer exist, like removed posts.
    def link_to_trackable(object, object_type)
      if object
        object_url = object.respond_to?(:url) ? object.url : object
        trackable_name = "#{object.class.model_name.human}: "
        safe_join([trackable_name, link_to(object, object_url, class: 'text-decoration-none')], '')
      else
        "a #{object_type.downcase} which does not exist anymore"
      end
    end
  end
end
