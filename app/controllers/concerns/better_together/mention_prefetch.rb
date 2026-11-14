# frozen_string_literal: true

module BetterTogether
  # Looks up which of a page's people the viewer may see in one query, for PeopleHelper#mention_profile_path.
  # Call prefetch_mention_visibility(people) before rendering a list of mentions to skip the per-person policy
  # check. The set only ever grants a link the policy would grant: a person missing from it still gets the full
  # PersonPolicy#show? check in the helper.
  module MentionPrefetch
    private

    def prefetch_mention_visibility(people)
      ids = Array(people).compact.map(&:id).uniq
      @mention_visible_ids = policy_scope(BetterTogether::Person).where(id: ids).pluck(:id).to_set
    end
  end
end
