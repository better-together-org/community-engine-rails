# frozen_string_literal: true

module BetterTogether
  # Search and filter service for Events index.
  # Filters by text (ILIKE name + description), category, status, date window,
  # order, and paginates. Inherits common search logic from ContentSearchFilter.
  class EventsSearchFilter < ContentSearchFilter
    def self.call(relation:, params:)
      new(resource_class: BetterTogether::Event, relation:, params:).call
    end

    private

    # Override: Events use 'description' as the ActionText field name
    def action_text_field
      'description'
    end

    # Override: Events translate :name (not :title) via Mobility
    def mobility_title_key
      'name'
    end

    # Override: Add status filtering, the recurring/one-time filter, and the
    # default upcoming date window
    def filter_by_resource_specific_status
      filter_by_status
      filter_by_recurring
      filter_by_date_range
    end

    # status accepts a single value or an array (union). Blank or 'all'
    # leaves the relation unfiltered; unknown values are ignored.
    def filter_by_status
      statuses = Array(params[:status]).map(&:to_s).reject(&:blank?)
      return @relation if statuses.empty? || statuses.include?('all')

      statuses &= resource_class.statuses.values
      return @relation if statuses.empty?

      @relation = @relation.where(status: statuses)
    end

    # Tri-state: blank leaves the relation unfiltered; 'true' restricts to
    # recurring events, 'false' to one-time events. Plain AR association
    # join, no raw SQL, per this repo's query standards.
    def filter_by_recurring
      case params[:recurring].to_s
      when 'true'
        @relation = @relation.left_joins(:recurrence).where.not(better_together_recurrences: { id: nil })
      when 'false'
        @relation = @relation.left_joins(:recurrence).where(better_together_recurrences: { id: nil })
      end
      @relation
    end

    # Default window: upcoming events (next_occurrence_at >= now). A truthy
    # `past` param flips the window to historical events
    # (next_occurrence_at < now). next_occurrence_at (not starts_at) is
    # override- and recurrence-aware — see Event#refresh_next_occurrence_at! —
    # so a recurring event whose original starts_at is long past still shows
    # as upcoming for as long as it keeps recurring.
    def filter_by_date_range
      next_occurrence_at = resource_class.arel_table[:next_occurrence_at]

      @relation = if past_requested?
                    @relation.where(next_occurrence_at.lt(Time.current))
                  else
                    @relation.where(next_occurrence_at.gteq(Time.current))
                  end
    end

    def past_requested?
      ActiveModel::Type::Boolean.new.cast(params[:past]).present?
    end

    # Override: Events support four date-based orderings.
    # soonest (default): next_occurrence_at asc; latest: next_occurrence_at desc;
    # newest: created_at desc; oldest: created_at asc.
    def order_by
      @relation = case params[:order_by]
                  when 'latest' then @relation.reorder(next_occurrence_at: :desc)
                  when 'newest' then @relation.reorder(created_at: :desc)
                  when 'oldest' then @relation.reorder(created_at: :asc)
                  else default_order_by
                  end
    end

    # Override: Default ordering for Events is soonest-first (next_occurrence_at asc)
    def default_order_by
      @relation.reorder(next_occurrence_at: :asc)
    end
  end
end
