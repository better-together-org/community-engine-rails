# frozen_string_literal: true

# app/controllers/better_together/navigation_items_controller.rb

module BetterTogether
  # Responds to requests for navigation items
  class NavigationItemsController < ApplicationController
    before_action :set_pages, only: %i[new edit create update]
    before_action :set_navigation_area
    before_action :set_navigation_item, only: %i[show edit update destroy]

    def index
      authorize ::BetterTogether::NavigationItem
      @navigation_items =
        policy_scope(::BetterTogether::NavigationItem).top_level.where(navigation_area: @navigation_area)
    end

    def show
      authorize @navigation_item
    end

    def new
      @navigation_item = new_navigation_item
      authorize @navigation_item
    end

    def edit
      authorize @navigation_item
    end

    def create
      @navigation_item = new_navigation_item
      @navigation_item.assign_attributes(navigation_item_params)
      authorize @navigation_item

      if @navigation_item.save
        redirect_to @navigation_area, notice: 'Navigation item was successfully created.'
      else
        render :new
      end
    end

    def update
      authorize @navigation_item

      if @navigation_item.update(navigation_item_params)
        redirect_to @navigation_area, notice: 'Navigation item was successfully updated.'
      else
        render :edit
      end
    end

    def destroy
      authorize @navigation_item
      @navigation_item.destroy
      redirect_to navigation_area_navigation_items_url(@navigation_area),
                  notice: 'Navigation item was successfully destroyed.'
    end

    private

    def parent_id_param
      params[:parent_id]
    end

    def new_navigation_item
      @navigation_area.navigation_items.new do |item|
        item.parent_id = parent_id_param if parent_id_param.present?
      end
    end

    def set_pages
      @pages = ::BetterTogether::Page.all
    end

    def set_navigation_area
      @navigation_area = ::BetterTogether::NavigationArea.friendly.find(params[:navigation_area_id])
      authorize @navigation_area
    end

    def set_navigation_item
      @navigation_item = ::BetterTogether::NavigationItem.friendly.find(params[:id])
      # Removed the authorize call from here as it's now in each action
    end

    def navigation_item_params
      params.require(:navigation_item).permit(:navigation_area_id, :title, :url, :icon, :position, :visible,
                                              :item_type, :linkable_id, :linkable_type, :parent_id)
    end
  end
end
