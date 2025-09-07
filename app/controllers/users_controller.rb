require "ostruct"

class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def profile
  end

  def update_profile
    if @user.update(profile_params)
      redirect_to profile_path, notice: "Profile updated successfully!"
    else
      render :profile, status: :unprocessable_entity
    end
  end

  def settings
  end

  def update_settings
    if @user.update(settings_params)
      redirect_to settings_path, notice: "Settings updated successfully!"
    else
      render :settings, status: :unprocessable_entity
    end
  end

  def billing
    # In a real application, you would fetch subscription data from Stripe here
    @subscription = current_user_subscription
    @payment_methods = current_user_payment_methods
  end

  private

  def set_user
    @user = current_user
  end

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :phone, :bio, :company, :job_title, :avatar)
  end

  def settings_params
    params.require(:user).permit(:email_notifications, :sms_notifications, :weekly_digest, :marketing_emails, :timezone, :language)
  end

  def current_user_subscription
    # Mock subscription data - replace with actual Stripe integration
    OpenStruct.new(
      plan: "Professional",
      price: 49,
      billing_cycle: "monthly",
      next_billing_date: 30.days.from_now,
      status: "active"
    )
  end

  def current_user_payment_methods
    # Mock payment methods - replace with actual Stripe integration
    [
      OpenStruct.new(
        type: "card",
        brand: "Visa",
        last4: "4242",
        expires: "12/2025",
        default: true
      )
    ]
  end
end
