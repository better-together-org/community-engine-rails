# frozen_string_literal: true

module BetterTogether
  class UsersController < FriendlyResourceController # rubocop:todo Style/Documentation
    before_action :set_user, only: %i[show edit update destroy]
    before_action :authorize_user, only: %i[show edit update destroy]
    after_action :verify_authorized, except: :index

    # GET /users
    def index
      authorize resource_class
      @users = policy_scope(resource_class.with_translations)
    end

    # GET /users/1
    def show; end

    # GET /users/new
    def new
      @user = resource_class.new
      authorize_user
    end

    # POST /users
    def create
      @user = resource_class.new(user_params)
      authorize_user

      if @user.save
        redirect_to @user, only_path: true, notice: 'User was successfully created.', status: :see_other
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /users/1/edit
    def edit; end

    # PATCH/PUT /users/1
    def update
      ActiveRecord::Base.transaction do
        if @user.update(user_params)
          redirect_to @user, only_path: true, notice: 'Profile was successfully updated.', status: :see_other
        else
          flash.now[:alert] = 'Please address the errors below.'
          render :edit, status: :unprocessable_entity
        end
      end
    end

    # DELETE /users/1
    def destroy
      @user.destroy
      redirect_to users_url, notice: 'User was successfully deleted.', status: :see_other
    end

    private

    # Adds a policy check for the user
    def authorize_user
      authorize @user
    end

    def set_user
      @user = set_resource_instance
    end

    def user_params
      params.require(:user).permit(:email)
    end

    def resource_class
      ::BetterTogether::User
    end
  end
end
