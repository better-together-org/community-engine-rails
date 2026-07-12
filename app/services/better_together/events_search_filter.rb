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

    # Override: Add status filtering and the default upcoming date window
    def filter_by_resource_specific_status
      filter_by_status
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

    # Default window: upcoming events (starts_at >= now). A truthy `past`
    # param flips the window to historical events (starts_at < now).
    def filter_by_date_range
      starts_at = resource_class.arel_table[:starts_at]

      @relation = if past_requested?
                    @relation.where(starts_at.lt(Time.current))
                  else
                    @relation.where(starts_at.gteq(Time.current))
                  end
    end

    def past_requested?
      ActiveModel::Type::Boolean.new.cast(params[:past]).present?
    end

    # Override: Events support four date-based orderings.
    # soonest (default): starts_at asc; latest: starts_at desc;
    # newest: created_at desc; oldest: created_at asc.
    def order_by
      @relation = case params[:order_by]
                  when 'latest' then @relation.reorder(starts_at: :desc)
                  when 'newest' then @relation.reorder(created_at: :desc)
                  when 'oldest' then @relation.reorder(created_at: :asc)
                  else default_order_by
                  end
    end

    # Override: Default ordering for Events is soonest-first (starts_at asc)
    def default_order_by
      @relation.reorder(starts_at: :asc)
    end
  end
end
