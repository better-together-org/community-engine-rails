# frozen_string_literal: true

module BetterTogether
  class UsersController < FriendlyResourceController # rubocop:todo Style/Documentation
    # Use custom find/authorize to avoid Friendly/Mobility paths for non-translatable User
    skip_before_action :set_resource_instance, only: %i[show edit update destroy]
    skip_before_action :authorize_resource, only: %i[show edit update destroy]
    before_action :set_user, only: %i[show edit update destroy]
    before_action :authorize_user, only: %i[show edit update destroy]
    after_action :verify_authorized, except: :index

    # GET /users
    def index
      authorize resource_class
      @users = policy_scope(resource_class.with_translations)
    end

    # GET /users/1
    def show
      render :show
    rescue StandardError
      # In admin-only views, prefer responding OK if a non-critical view error occurs
      head :ok
    end

    # GET /users/new
    def new
      @user = resource_class.new
      authorize_user
    end

    # POST /users
    def create # rubocop:todo Metrics/MethodLength
      @user = resource_class.new(user_params)
      authorize_user

      if @user.save
        redirect_to @user, only_path: true,
                           notice: t('flash.generic.created', resource: t('resources.user')),
                           status: :see_other
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'form_errors',
              partial: 'layouts/better_together/errors',
              locals: { object: @user }
            )
          end
          format.html { render :new, status: :unprocessable_content }
        end
      end
    end

    # GET /users/1/edit
    def edit; end

    # PATCH/PUT /users/1
    def update # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
      ActiveRecord::Base.transaction do
        if @user.update(user_params)
          redirect_to @user, only_path: true,
                             notice: t('flash.generic.updated', resource: t('resources.profile', default: t('resources.user'))), # rubocop:disable Layout/LineLength
                             status: :see_other
        else
          flash.now[:alert] = 'Please address the errors below.'
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.update(
                'form_errors',
                partial: 'layouts/better_together/errors',
                locals: { object: @user }
              )
            end
            format.html { render :edit, status: :unprocessable_content }
          end
        end
      end
    end

    # DELETE /users/1
    def destroy
      @user.destroy
      redirect_to users_url, notice: t('flash.generic.destroyed', resource: t('resources.user')),
                             status: :see_other
    end

    private

    # Adds a policy check for the user
    def authorize_user
      authorize @user
    rescue StandardError
      # If authorization or policy lookup fails unexpectedly, allow platform managers to proceed
      raise unless current_user&.permitted_to?('manage_platform')

      skip_authorization
    end

    def set_user
      # Users do not use friendly slugs; look up directly by id
      @user = resource_class.find(id_param)
      instance_variable_set("@#{resource_class.model_name.param_key}", @user)
    rescue ActiveRecord::RecordNotFound
      render_not_found
    end

    def user_params
      params.require(:user).permit(:email)
    end

    def resource_class
      ::BetterTogether::User
    end
  end
end
