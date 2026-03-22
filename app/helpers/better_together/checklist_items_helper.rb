# frozen_string_literal: true

module BetterTogether
  # Helper methods for rendering and formatting checklist items in views.
  #
  # Provides view helper utilities used by checklist-related templates.
  module ChecklistItemsHelper
    # Return a relation of checklist items scoped for the provided checklist and optional parent_id.
    # This helper is available in views and mirrors the controller helper implementation; it
    # ensures ordering by position and memoizes the relation per-request.
    def checklist_items_for(checklist, parent_id: nil)
      @__checklist_items_cache ||= {}
      key = [checklist.id, parent_id]
      return @__checklist_items_cache[key] if @__checklist_items_cache.key?(key)

      scope = policy_scope(::BetterTogether::ChecklistItem)
      scope = scope.where(checklist: checklist)
      scope = parent_id.nil? ? scope.where(parent_id: nil) : scope.where(parent_id: parent_id)

      scope = scope.with_translations.reorder(:position)

      @__checklist_items_cache[key] = scope
    end

    # Build an option title for a checklist item including depth-based prefix and slug.
    # Example: "— — Subitem label (subitem-slug)"
    def checklist_item_option_title(item)
      prefix = '— ' * item.depth.to_i
      label = item.label.presence || t('better_together.checklist_items.untitled', default: 'Untitled item')
      "#{prefix}#{label} (#{item.slug})"
    end
  end
end
