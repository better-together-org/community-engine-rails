module BetterTogether
  module ChecklistItemsHelper
    # Build an option title for a checklist item including depth-based prefix and slug.
    # Example: "— — Subitem label (subitem-slug)"
    def checklist_item_option_title(item)
      prefix = '— ' * item.depth.to_i
      label = item.label.presence || t('better_together.checklist_items.untitled', default: 'Untitled item')
      "#{prefix}#{label} (#{item.slug})"
    end
  end
end
