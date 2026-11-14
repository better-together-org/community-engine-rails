# frozen_string_literal: true

module BetterTogether
  class ShortLinkRedirectsController < ApplicationController # rubocop:todo Style/Documentation
    skip_before_action :authenticate_user!, raise: false

    def show
      short_link = find_short_link
      return render_not_found unless short_link&.active_and_unexpired?

      record_visit(short_link)
      redirect_to short_link.target_url, status: :found, allow_other_host: true
    end

    private

    def find_short_link
      BetterTogether::ShortLink
        .where(platform: Current.platform)
        .find_by(code: params[:code])
    end

    def record_visit(short_link)
      BetterTogether::Metrics::TrackShortLinkVisitJob.perform_later(visit_payload(short_link))
      short_link.increment!(:click_count)
      response.set_header('X-Robots-Tag', 'noindex')
    end

    def visit_payload(short_link) # rubocop:disable Metrics/MethodLength
      {
        'short_link_id' => short_link.id,
        'platform_id' => Current.platform.id,
        'referrer' => request.referer,
        'user_agent' => request.user_agent,
        'remote_addr' => anonymize_ip(request.remote_ip),
        'logged_in' => respond_to?(:user_signed_in?) && user_signed_in?,
        'visited_at' => Time.current.iso8601
      }
    end

    def render_not_found
      render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
    end

    def anonymize_ip(ip)
      addr = IPAddr.new(ip)
      addr.ipv4? ? addr.mask(24).to_s : addr.mask(48).to_s
    rescue IPAddr::Error
      nil
    end
  end
end
