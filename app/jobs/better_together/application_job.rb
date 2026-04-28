# frozen_string_literal: true

module BetterTogether
  class ApplicationJob < ActiveJob::Base
    discard_on ActiveStorage::FileNotFoundError
  end
end
