module BetterTogether
  class NavigationAreasController < ApplicationController
    before_action :set_navigation_area, only: [:show, :edit, :update, :destroy]

    def index
      authorize ::BetterTogether::NavigationArea
      @navigation_areas = policy_scope(::BetterTogether::NavigationArea)
    end

    def show
      authorize @navigation_area
    end

    def new
      @navigation_area = ::BetterTogether::NavigationArea.new
      authorize @navigation_area
    end

    def edit
      authorize @navigation_area
    end

    def create
      @navigation_area = ::BetterTogether::NavigationArea.new(navigation_area_params)
      authorize @navigation_area

      if @navigation_area.save
        redirect_to @navigation_area, notice: 'Navigation area was successfully created.'
      else
        render :new
      end
    end

    def update
      authorize @navigation_area

      if @navigation_area.update(navigation_area_params)
        redirect_to @navigation_area, notice: 'Navigation area was successfully updated.'
      else
        render :edit
      end
    end

    def destroy
      authorize @navigation_area
      @navigation_area.destroy
      redirect_to navigation_areas_url, notice: 'Navigation area was successfully destroyed.'
    end

    private

    def set_navigation_area
      @navigation_area = ::BetterTogether::NavigationArea.friendly.find(params[:id])
      # The call to `authorize` is removed from here and placed in each action
    end

    def navigation_area_params
      params.require(:navigation_area).permit(:name, :slug, :visible, :style, :protected)
    end
  end
end
