# frozen_string_literal: true

module BetterTogether
  # Admin CRUD and bulk import for a platform's redirects.
  class RedirectsController < ApplicationController
    before_action :set_platform
    before_action :set_redirect, only: %i[edit update destroy]
    after_action :verify_authorized

    # GET /host/platforms/:platform_id/redirects
    def index
      authorize @platform.redirects.build
      @redirects = filtered_redirects.page(params[:page]).per(50)
    end

    def new
      @redirect = @platform.redirects.build
      authorize @redirect
    end

    def edit
      authorize @redirect
    end

    def create
      @redirect = @platform.redirects.build(redirect_params)
      authorize @redirect

      if @redirect.save
        redirect_to platform_redirects_path(@platform), status: :see_other, notice: t('better_together.redirects.created')
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @redirect

      if @redirect.update(redirect_params)
        redirect_to platform_redirects_path(@platform), status: :see_other, notice: t('better_together.redirects.updated')
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @redirect
      @redirect.destroy
      redirect_to platform_redirects_path(@platform), status: :see_other, notice: t('better_together.redirects.destroyed')
    end

    # GET /host/platforms/:platform_id/redirects/import
    def new_import
      authorize @platform.redirects.build
    end

    # POST /host/platforms/:platform_id/redirects/import
    def create_import
      authorize @platform.redirects.build
      @report = Redirects::Importer.call(platform: @platform, rows: import_rows, source: 'import',
                                         mode: params[:mode] == 'upsert' ? :upsert : :add_only,
                                         dry_run: params[:commit_import].blank?)
      render :new_import, status: :ok
    end

    private

    def filtered_redirects
      scope = @platform.redirects.order(:from_path)
      return scope if params[:q].blank?

      scope.where(Redirect.arel_table[:from_path].matches("%#{Redirect.sanitize_sql_like(params[:q])}%"))
    end

    def set_platform
      @platform = Platform.friendly.find(params[:platform_id])
    end

    def set_redirect
      @redirect = @platform.redirects.find(params[:id])
    end

    def redirect_params
      params.require(:redirect).permit(:from_path, :to_path, :status, :active, :preserve_query, :note)
    end

    # One redirect per line: from,to[,status]. Blank lines and lines starting with # are ignored.
    def import_rows
      params[:rows].to_s.lines.filter_map do |line|
        line = line.strip
        next if line.blank? || line.start_with?('#')

        from, to, status = CSV.parse_line(line)
        { from_path: from, to_path: to, status: status.presence || 301 }
      rescue CSV::MalformedCSVError
        { from_path: line, to_path: nil, status: 301 }
      end
    end
  end
end
