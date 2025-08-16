# frozen_string_literal: true

class ApplicationNotifier < Noticed::Event
  def deliver_now(recipient)
    deliver(recipient)
  end
end
