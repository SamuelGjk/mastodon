# frozen_string_literal: true

class Api::V1::Accounts::CredentialsController < Api::BaseController
  before_action -> { doorkeeper_authorize! :read }, except: [:update]
  before_action -> { doorkeeper_authorize! :write }, only: [:update]
  before_action :require_user!

  def show
    @account = current_account
    render json: @account, serializer: REST::CredentialAccountSerializer
  end

  def update
    @account = current_account
    UpdateAccountService.new.call(@account, account_params, raise_error: true)
    UserSettingsDecorator.new(current_user).update(user_settings_params) if user_settings_params
    ActivityPub::UpdateDistributionWorker.perform_async(@account.id)
    render json: @account, serializer: REST::CredentialAccountSerializer
  end

  private

  def account_params
    params.permit(:display_name, :note, :avatar, :header, :locked, fields_attributes: [:name, :value])
  end

  def user_settings_params
    return nil unless params.key?(:source)

    source_params = params.require(:source)

    {
      'setting_default_privacy' => source_params.fetch(:privacy, @account.user.setting_default_privacy),
      'setting_default_sensitive' => source_params.fetch(:sensitive, @account.user.setting_default_sensitive),
    }
  end
end
