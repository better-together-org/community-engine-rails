# frozen_string_literal: true

module BetterTogether
  class CitationExportsController < ApplicationController
    CITEABLE_TYPES = {
      'page' => BetterTogether::Page,
      'post' => BetterTogether::Post,
      'event' => BetterTogether::Event,
      'call_for_interest' => BetterTogether::CallForInterest,
      'agreement' => BetterTogether::Agreement,
      'calendar' => BetterTogether::Calendar,
      'joatu_request' => BetterTogether::Joatu::Request,
      'joatu_offer' => BetterTogether::Joatu::Offer,
      'joatu_agreement' => BetterTogether::Joatu::Agreement
    }.freeze

    before_action :set_citeable

    def show
      authorize @citeable, :show?

      case export_style
      when 'csl'
        render json: {
          format: 'csl-json',
          citeable: {
            key: params[:citeable_key],
            id: @citeable.id,
            label: @citeable.to_s
          },
          citations: @citeable.citations_as_csl_json
        }
      when 'apa', 'mla'
        send_data @citeable.citation_export_lines(export_style).join("\n"),
                  filename: export_filename(export_style),
                  type: 'text/plain; charset=UTF-8',
                  disposition: 'inline'
      else
        render json: { error: 'Unsupported citation export style' }, status: :unprocessable_entity
      end
    end

    private

    def set_citeable
      klass = CITEABLE_TYPES[params[:citeable_key]]
      return render_not_found unless klass

      @citeable = if klass.respond_to?(:friendly)
                    klass.friendly.find(params[:id])
                  else
                    klass.find(params[:id])
                  end
    rescue ActiveRecord::RecordNotFound
      render_not_found
    end

    def export_style
      params[:style].presence || 'csl'
    end

    def export_filename(style)
      "#{params[:citeable_key]}-#{@citeable.id}-citations.#{style == 'csl' ? 'json' : 'txt'}"
    end
  end
end
