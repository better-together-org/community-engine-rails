# frozen_string_literal: true

module BetterTogether
  class CategoriesController < FriendlyResourceController
    before_action :set_model_instance, only: %i[show edit update destroy]
    before_action :authorize_category, only: %i[show edit update destroy]
    after_action :verify_authorized, except: :index

    # GET /categories
    def index
      authorize resource_class
      @categories = resource_class.all
    end

    # GET /categories/1
    def show; end

    # GET /categories/new
    def new
      @category = resource_class.new
      authorize_category
    end

    # GET /categories/1/edit
    def edit; end

    # POST /categories
    def create
      @category = resource_class.new(category_params)
      authorize_category

      if @category.save
        redirect_to @category, notice: 'Category was successfully created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /categories/1
    def update
      if @category.update(category_params)
        redirect_to @category, notice: 'Category was successfully updated.', status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /categories/1
    def destroy
      @category.destroy!
      redirect_to categories_url, notice: 'Category was successfully destroyed.', status: :see_other
    end

    protected

    # Adds a policy check for the category
    def authorize_category
      authorize @category
    end

    def set_model_instance
      @category = set_resource_instance
    end

    # Only allow a list of trusted parameters through.
    def category_params
      permitted = [
        *resource_class.extra_permitted_attributes
      ]

      params.require(resource_class.name.demodulize.underscore.to_sym).permit(permitted)
    end

    def resource_class
      ::BetterTogether::Category
    end

    def resource_collection
      resource_class.with_translations
    end
  end
end
