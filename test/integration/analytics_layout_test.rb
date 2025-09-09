require "test_helper"

class AnalyticsLayoutTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
  end

  test "dashboard displays without NaN values" do
    get dashboard_path
    assert_response :success

    # The main fix: ensure no NaN values appear in the dashboard
    assert_not_includes response.body, "NaN", "Dashboard should not contain NaN values"

    # Verify key sections are present
    assert_includes response.body, "Performance Score"
    assert_includes response.body, "AI Insights"
  end

  test "analytics page displays without NaN values" do
    get dashboard_analytics_path
    assert_response :success

    # Check that we don't have any NaN values
    assert_not_includes response.body, "NaN"

    # Check for key sections
    assert_includes response.body, "Analytics Overview"
  end
end
