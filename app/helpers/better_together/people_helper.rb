# frozen_string_literal: true

module BetterTogether
  module PeopleHelper # rubocop:todo Style/Documentation
    # Safe to call from contexts with no Warden/current_user, e.g. Comment's
    # broadcast_append_later_to render (bare ApplicationController.renderer) or a
    # mailer view — both lack Pundit's current_user. Falls back to no link instead
    # of raising, matching the rescue Devise::MissingWarden idiom already used in
    # CommentsHelper/ContentActionsHelper for the same reason.
    def mention_profile_path(person)
      return nil unless person.present?
      return nil unless respond_to?(:policy) && policy(person).show?

      person_path(person)
    rescue Devise::MissingWarden
      nil
    end
  end
end
