# frozen_string_literal: true

module BetterTogether
  # Admin CRUD for platform head and body code snippets. Scoped to one platform; every action needs
  # manage_platform_code on that platform (see PlatformSnippetPolicy).
  class PlatformSnippetsController < ApplicationController
    before_action :set_platform
    before_action :set_snippet, only: %i[edit update destroy move]
    after_action :verify_authorized

    def index
      authorize PlatformSnippet.new(platform: @platform)
      @snippets = @platform.platform_snippets.reload
      @audits = @platform.platform_snippet_audits.recent.limit(20)
    end

    def new
      @snippet = PlatformSnippet.new(platform: @platform, location: 'head_end', kind: 'script_inline')
      authorize @snippet
    end

    def edit
      authorize @snippet
    end

    def create
      @snippet = PlatformSnippet.new(snippet_params.merge(platform: @platform))
      authorize @snippet
      save_snippet(:new) { @snippet.save }
    end

    def update
      authorize @snippet
      @snippet.assign_attributes(snippet_params)
      save_snippet(:edit) { @snippet.save }
    end

    def destroy
      authorize @snippet
      @snippet.destroy
      redirect_to platform_platform_snippets_path(@platform), status: :see_other,
                                                              notice: t('better_together.platform_snippets.destroyed')
    end

    # Swaps the snippet with its neighbour in the same location.
    def move
      authorize @snippet
      neighbour = neighbour_for(@snippet, params[:direction])
      swap_positions(@snippet, neighbour) if neighbour
      redirect_to platform_platform_snippets_path(@platform), status: :see_other
    end

    # Platform-wide kill switch for all snippets.
    def toggle_all
      authorize PlatformSnippet.new(platform: @platform), :toggle_all?
      @platform.snippets_enabled = ActiveModel::Type::Boolean.new.cast(params[:enabled])
      @platform.save!(validate: false)
      redirect_to platform_platform_snippets_path(@platform), status: :see_other,
                                                              notice: t('better_together.platform_snippets.switch_updated')
    end

    private

    def save_snippet(failed_view)
      @snippet.allow_csp_origin = nil unless policy(@snippet).allow_origin?
      saved = PlatformSnippet.transaction do
        ok = yield
        allow_origin!(@snippet) if ok && @snippet.script_src? && @snippet.allow_csp_origin
        ok
      end
      if saved
        redirect_to platform_platform_snippets_path(@platform), status: :see_other,
                                                                notice: t('better_together.platform_snippets.saved')
      else
        render failed_view, status: :unprocessable_content
      end
    end

    def allow_origin!(snippet)
      origin = snippet.src_origin
      return if @platform.csp_script_src.include?(origin)

      @platform.update!(csp_script_src_text: (@platform.csp_script_src + [origin]).join("\n"))
    end

    def neighbour_for(snippet, direction)
      siblings = @platform.platform_snippets.where(location: snippet.location)
      if direction == 'up'
        siblings.where(position: ...snippet.position).reorder(position: :desc).first
      else
        siblings.where(position: (snippet.position + 1)..).reorder(:position).first
      end
    end

    def swap_positions(first, second)
      PlatformSnippet.transaction do
        first_position = first.position
        first.update!(position: second.position)
        second.update!(position: first_position)
      end
    end

    def set_platform
      @platform = Platform.friendly.find(params[:platform_id])
    end

    def set_snippet
      @snippet = @platform.platform_snippets.find(params[:id])
    end

    def snippet_params
      params.require(:platform_snippet).permit(:name, :location, :kind, :content, :src, :enabled,
                                               :consent_category, :applies_to, :notes, :allow_csp_origin)
    end
  end
end
