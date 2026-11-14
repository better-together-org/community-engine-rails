# frozen_string_literal: true

module BetterTogether
  module Geography
    # Map subtype for any Locatable::One-including mappable (Event today; future
    # Joatu Offer/Request once they adopt Locatable::One). No mappable_class
    # override needed here — the base Map#leaflet_points delegation to `mappable`
    # already works once the mappable includes Locatable::One, which provides its
    # own leaflet_points/spaces methods.
    class LocatableMap < ::BetterTogether::Geography::Map
    end
  end
end
