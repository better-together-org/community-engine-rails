# frozen_string_literal: true

module BetterTogether
  # Lets an index list only the records located in one place: /events?settlement=<identifier> (the list behind
  # the settlement page Events tab), likewise /posts?settlement=<identifier>.
  #
  # The set is `located_in(place)` applied to the policy scope, so visibility never widens, and the index's own
  # filters, ordering and paging apply on top. The place is looked up through its policy scope, so a place the
  # viewer cannot see is a 404 and its name is never shown in the heading.
  #
  # Uses the FramedIndex hooks (`index_scope_params` keeps the param through the filter form, `index_heading`
  # titles the list), so it must be *prepended* after FramedIndex is included, because the including controllers
  # define `policy_scoped_resources` themselves:
  #
  #   include FramedIndex
  #   prepend PlaceScopedIndex
  module PlaceScopedIndex
    extend ActiveSupport::Concern

    # Query param => place class. Allow-listed, never derived from the request. To scope by another level, add it
    # here (the class must be Placeable, have an `identifier`, and have a policy scope).
    def self.place_classes
      { settlement: ::BetterTogether::Geography::Settlement }
    end

    prepended do
      before_action :load_scoped_place, only: :index
      helper_method :scoped_place
    end

    private

    attr_reader :scoped_place

    def load_scoped_place
      param, klass = PlaceScopedIndex.place_classes.find { |name, _| params[name].present? }
      return unless param

      value = params[param]
      raise ActiveRecord::RecordNotFound unless value.is_a?(String)

      @scoped_place_param = param
      @scoped_place = policy_scope(klass).find_by!(identifier: value.downcase)
    end

    def index_scope_params
      scoped_place ? super.merge(@scoped_place_param => scoped_place.identifier) : super
    end

    def index_heading
      return super unless scoped_place

      if controller_name == 'posts'
        t('better_together.geography.place_scoped_index.posts_heading', name: scoped_place.name)
      else
        t('better_together.geography.place_scoped_index.events_heading', name: scoped_place.name)
      end
    end

    def policy_scoped_resources
      scope = super
      scoped_place ? scope.located_in(scoped_place) : scope
    end
  end
end
