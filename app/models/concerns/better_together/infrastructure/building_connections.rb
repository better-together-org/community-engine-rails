# frozen_string_literal: true

module BetterTogether
  module Infrastructure
    module BuildingConnections # rubocop:todo Style/Documentation
      extend ActiveSupport::Concern

      included do
        include ::BetterTogether::Geography::Mappable

        has_many :building_connections,
                 -> { order(:primary_flag, :position) },
                 class_name: 'BetterTogether::Infrastructure::BuildingConnection',
                 as: :connection,
                 dependent: :destroy

        has_many :buildings, through: :building_connections

        accepts_nested_attributes_for :building_connections,
                                      allow_destroy: true, reject_if: :all_blank
      end

      class_methods do
        def extra_permitted_attributes
          super + [
            building_connections_attributes: ::BetterTogether::Infrastructure::BuildingConnection.permitted_attributes(
              id: true, destroy: true
            )
          ]
        end
      end

      def leaflet_points # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        buildings.joins(:space).map do |building|
          point = building.to_leaflet_point
          next if point.nil?

          point.merge(
            label: "<a href='#{Rails.application.routes.url_helpers.polymorphic_path(
              self,
              locale: I18n.locale
            )}' class='text-decoration-none'><strong>#{name}#{building.address.text_label if building.address.text_label.present? }</strong></a>",
            popup_html: "<a href='#{Rails.application.routes.url_helpers.polymorphic_path(
              self,
              locale: I18n.locale
            )}' class='text-decoration-none'><strong>#{name}#{" - #{building.address.text_label}" if building.address.text_label.present? }</strong></a><br>#{building.address.to_formatted_s(excluded: [:display_label])}"
          )
        end.compact
      end

      def primary_building
        return if building_connections.empty?

        @primary_building ||= building_connections.primary_record(id)&.building
      end

      def primary_address
        @primary_address ||= primary_building&.address
      end

      def spaces
        @spaces ||= buildings.includes(:space).map(&:space).flatten.uniq
      end
    end
  end
end
