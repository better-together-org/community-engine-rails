# frozen_string_literal: true

module BetterTogether
  # Concern that when included allows model to be set as host
  module Host
    extend ActiveSupport::Concern

    included do
      # before_validation :set_as_host # this was causing problems wdhen the seeds created communities
      validate :single_host_record

      scope :host, -> { where(host: true) }
    end

    def host?
      host
    end

    # Method to set the host attribute to true only if there is no host community
    def set_as_host
      return if self.class.where(host: true).exists?

      self.host = true
    end

    protected

    # Validate that only one record can be marked as host
    def single_host_record
      return unless host && self.class.where.not(id:).exists?(host: true)

      errors.add(:host, 'can only be set for one record')
    end
  end
end
