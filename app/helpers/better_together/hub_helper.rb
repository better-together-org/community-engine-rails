# frozen_string_literal: true

module BetterTogether
  # Helper methods used for displaying the Community Hub
  module HubHelper
    def activities
      BetterTogether::ActivityPolicy::Scope.new(current_user, PublicActivity::Activity).resolve
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
