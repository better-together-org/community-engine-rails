# frozen_string_literal: true

module BetterTogether
  # Helper methods for platform invitations views
  module PlatformInvitationsHelper
    def sortable_column_header_for_invitations(column, label, platform)
      sort_info = calculate_sort_info_for_invitations(column)

      link_to build_sort_path_for_invitations(column, sort_info[:direction], platform),
              sort_link_options_for_invitations do
        build_sort_content_for_invitations(label, sort_info[:icon_class])
      end
    end

    def calculate_sort_info_for_invitations(column)
      if currently_sorted_by_invitations?(column)
        active_column_sort_info_for_invitations
      else
        default_column_sort_info_for_invitations
      end
    end

    def currently_sorted_by_invitations?(column)
      params[:sort_by] == column.to_s
    end

    def active_column_sort_info_for_invitations
      current_direction = params[:sort_direction]
      {
        direction: current_direction == 'asc' ? 'desc' : 'asc',
        icon_class: current_direction == 'asc' ? 'fas fa-sort-up' : 'fas fa-sort-down'
      }
    end

    def default_column_sort_info_for_invitations
      {
        direction: 'asc',
        icon_class: 'fas fa-sort text-muted'
      }
    end

    def build_sort_path_for_invitations(column, direction, platform) # rubocop:todo Metrics/MethodLength
      platform_platform_invitations_path(platform,
                                         filters: {
                                           search: current_search_filter_for_invitations,
                                           status: current_status_filter_for_invitations,
                                           valid_from: current_valid_from_filter_for_invitations.presence,
                                           valid_until: current_valid_until_filter_for_invitations.presence,
                                           accepted_at: current_accepted_at_filter_for_invitations.presence,
                                           last_sent: current_last_sent_filter_for_invitations.presence
                                         }.compact_blank,
                                         sort_by: column,
                                         sort_direction: direction,
                                         page: params[:page])
    end

    def sort_link_options_for_invitations
      {
        class: 'text-decoration-none d-flex align-items-center justify-content-between',
        data: {
          turbo_frame: 'platform_invitations_content',
          turbo_prefetch: false # disable Turbo prefetch for these links
        }
      }
    end

    def build_sort_content_for_invitations(label, icon_class)
      safe_join([
                  content_tag(:span, label),
                  content_tag(:i, '', class: icon_class, 'aria-hidden': true)
                ])
    end

    def current_search_filter_for_invitations
      filter_params[:search] || params[:search]
    end

    def current_status_filter_for_invitations
      filter_params[:status] || params[:status]
    end

    def current_valid_from_filter_for_invitations
      filter = filter_params[:valid_from] || {}
      {
        from: filter[:from].presence,
        to: filter[:to].presence
      }.compact
    end

    def current_valid_until_filter_for_invitations
      filter = filter_params[:valid_until] || {}
      {
        from: filter[:from].presence,
        to: filter[:to].presence
      }.compact
    end

    def current_accepted_at_filter_for_invitations
      filter = filter_params[:accepted_at] || {}
      {
        from: filter[:from].presence,
        to: filter[:to].presence
      }.compact
    end

    def current_last_sent_filter_for_invitations
      filter = filter_params[:last_sent] || {}
      {
        from: filter[:from].presence,
        to: filter[:to].presence
      }.compact
    end

    private

    def filter_params
      params[:filters] || {}
    end
  end
end
