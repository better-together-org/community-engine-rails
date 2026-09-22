# frozen_string_literal: true

module BetterTogether
  # Base Action Mailbox router for the engine. Host apps can subclass this as
  # their root ApplicationMailbox, mirroring ApplicationController and
  # ApplicationMailer.
  class ApplicationMailbox < ActionMailbox::Base
    routing all: 'BetterTogether::Router'
  end
end
