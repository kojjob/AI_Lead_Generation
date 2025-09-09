require "test_helper"

class NanFixTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "dashboard controller analytics data does not contain NaN values" do
    user = users(:one)
    sign_in user

    # Test the controller directly
    controller = DashboardController.new
    controller.instance_variable_set(:@user, user)
    controller.send(:set_dashboard_data)

    analytics_data = controller.instance_variable_get(:@analytics_data)

    # Convert all data to string and check for NaN
    data_string = analytics_data.to_s
    assert_not_includes data_string, "NaN", "Analytics data should not contain NaN values"

    # Check specific values are numeric
    assert analytics_data[:leads][:total_leads].is_a?(Integer)
    assert analytics_data[:leads][:this_month].is_a?(Integer)
    assert analytics_data[:leads][:last_month].is_a?(Integer)
    assert analytics_data[:leads][:growth_rate].is_a?(Numeric)

    # Check conversion rate is numeric
    assert analytics_data[:conversions][:conversion_rate].is_a?(Numeric)

    # Check insights exist
    assert analytics_data[:insights].is_a?(Array)
    assert analytics_data[:insights].length > 0
  end

  test "performance score calculation works correctly" do
    user = users(:one)

    controller = DashboardController.new
    controller.instance_variable_set(:@user, user)
    controller.send(:set_dashboard_data)

    analytics_data = controller.instance_variable_get(:@analytics_data)

    # Calculate performance score like in the view
    performance_score = if analytics_data[:leads][:total_leads] > 0
                          [ ((analytics_data[:conversions][:conversion_rate] +
                             analytics_data[:leads][:this_month] * 2 +
                             (analytics_data[:keywords]&.count || 0) * 3) / 3).round, 100 ].min
    else
                          85
    end

    assert performance_score.is_a?(Integer)
    assert performance_score >= 0
    assert performance_score <= 100
    refute_equal "NaN", performance_score.to_s
  end
end
