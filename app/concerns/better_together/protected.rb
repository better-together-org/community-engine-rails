
module BetterTogether
  module Protected
    extend ActiveSupport::Concern

    included do
      validates :protected, inclusion: { in: [true, false] }
    end

    def protected?
      protected
    end

  end
end
