require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
  end

  test "should get index" do
    get dashboard_path
    assert_response :success
  end

  test "should get analytics" do
    get dashboard_analytics_path, as: :html
    assert_response :success
  end

  test "analytics data should have proper structure" do
    get dashboard_analytics_path, as: :html
    assert_response :success

    # Check that analytics data is assigned
    assert_not_nil assigns(:analytics_data)

    # Check structure
    analytics_data = assigns(:analytics_data)
    assert analytics_data.key?(:leads)
    assert analytics_data.key?(:conversions)
    assert analytics_data.key?(:keywords)
    assert analytics_data.key?(:integrations)
    assert analytics_data.key?(:insights)

    # Check leads data structure
    leads_data = analytics_data[:leads]
    assert leads_data.key?(:total_leads)
    assert leads_data.key?(:this_month)
    assert leads_data.key?(:last_month)
    assert leads_data.key?(:growth_rate)

    # Check insights data
    insights_data = analytics_data[:insights]
    assert insights_data.is_a?(Array)
  end

  test "should handle empty data gracefully" do
    # Test with user that has no keywords/leads
    new_user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in new_user

    get dashboard_path
    assert_response :success

    analytics_data = assigns(:analytics_data)
    assert_equal 0, analytics_data[:leads][:total_leads]
    assert_not_nil analytics_data[:insights]
  end

  test "widgets endpoint should return json" do
    get dashboard_widgets_path, as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("recent_leads")
    assert json_response.key?("keyword_performance")
    assert json_response.key?("stats")
  end
end
