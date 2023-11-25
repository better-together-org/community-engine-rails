# app/controllers/better_together/navigation_items_controller.rb

module BetterTogether
  class NavigationItemsController < ApplicationController
    before_action :set_pages, only: [:new, :edit, :create, :update]
    before_action :set_navigation_area
    before_action :set_navigation_item, only: [:show, :edit, :update, :destroy]

    def index
      @navigation_items = policy_scope(::BetterTogether::NavigationItem)
    end

    def show; end
    def new; @navigation_item = @navigation_area.navigation_items.new; end
    def edit; end

    def create
      @navigation_item = ::BetterTogether::NavigationItem.new(navigation_item_params)

      if @navigation_item.save
        redirect_to @navigation_area, notice: 'Navigation item was successfully created.'
      else
        render :new
      end
    end

    def update
      if @navigation_item.update(navigation_item_params)
        redirect_to @navigation_area, notice: 'Navigation item was successfully updated.'
      else
        render :edit
      end
    end

    def destroy
      @navigation_item.destroy
      redirect_to navigation_area_navigation_items_url, notice: 'Navigation item was successfully destroyed.'
    end

    private

    def set_pages
      @pages = ::BetterTogether::Page.all
    end

    def set_navigation_area
      @navigation_area = ::BetterTogether::NavigationArea.friendly.find(params[:navigation_area_id])
      authorize @navigation_area
    end

    def set_navigation_item
      @navigation_item = ::BetterTogether::NavigationItem.friendly.find(params[:id])
      authorize @navigation_item
    end

    def navigation_item_params
      params.require(:navigation_item).permit(:navigation_area_id, :title, :url, :icon, :position, :visible, :item_type, :linkable_id, :linkable_type)
    end
  end
end
