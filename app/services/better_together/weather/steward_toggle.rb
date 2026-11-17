# frozen_string_literal: true

module BetterTogether
  module Weather
    # Switches the host weather feature, a source or a location on or off for a host steward and
    # records who changed what, with the value before and after, as a private Activity.
    class StewardToggle
      KEYS = {
        'BetterTogether::Platform' => 'weather.feature.toggled',
        'BetterTogether::Weather::Source' => 'weather.source.toggled',
        'BetterTogether::Weather::Location' => 'weather.location.toggled'
      }.freeze

      Result = Struct.new(:changed, :before, :after, keyword_init: true) do
        alias_method :changed?, :changed
      end

      def self.call(record, enabled:, actor:)
        new(record, enabled:, actor:).call
      end

      def initialize(record, enabled:, actor:)
        @record = record
        @enabled = ActiveModel::Type::Boolean.new.cast(enabled) ? true : false
        @actor = actor
      end

      def call
        @record.with_lock do
          before = currently_enabled?
          next Result.new(changed: false, before:, after: before) if before == @enabled

          write_value
          record_activity(before)
          Result.new(changed: true, before:, after: @enabled)
        end
      end

      private

      def platform?
        @record.is_a?(BetterTogether::Platform)
      end

      def currently_enabled?
        (platform? ? @record.weather_enabled : @record.enabled) != false
      end

      # The platform skips validation like the snippet switch: only one settings flag changes.
      def write_value
        if platform?
          @record.weather_enabled = @enabled
          @record.save!(validate: false)
        else
          @record.update!(enabled: @enabled)
        end
      end

      def record_activity(before)
        BetterTogether::Activity.create!(
          trackable: @record, owner: @actor, key: KEYS.fetch(@record.class.base_class.name),
          privacy: 'private', platform: Current.host_platform,
          parameters: { 'attribute' => platform? ? 'weather_enabled' : 'enabled',
                        'before' => before, 'after' => @enabled, 'label' => label }
        )
      end

      def label
        case @record
        when BetterTogether::Weather::Source then @record.identifier
        when BetterTogether::Weather::Location then "#{@record.settlement&.name} (#{@record.external_ref})"
        else @record.name
        end
      end
    end
  end
end
