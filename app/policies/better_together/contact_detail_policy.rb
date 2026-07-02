# frozen_string_literal: true

module BetterTogether
  class ContactDetailPolicy < PlatformRecordPolicy # rubocop:todo Style/Documentation
    def create?
      true # Adjust as per your authorization logic
    end

    def destroy?
      true # Adjust as per your authorization logic
    end

    class Scope < PlatformRecordPolicy::Scope
    end
  end
end
