# frozen_string_literal: true

# Root mailbox for the dummy host app. Real host apps should mirror this
# pattern when opting into CE inbound mail.
class ApplicationMailbox < BetterTogether::ApplicationMailbox
end
