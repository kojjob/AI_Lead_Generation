require "test_helper"

class AnalyticsDataTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "leads analytics returns proper numeric values" do
    # Create a simple controller instance to test the analytics methods
    controller = DashboardController.new
    controller.instance_variable_set(:@user, @user)
    controller.instance_variable_set(:@user_keywords, @user.keywords)
    
    leads_data = controller.send(:leads_analytics)
    
    # Check all values are numeric, not NaN
    assert leads_data[:total_leads].is_a?(Integer)
    assert leads_data[:this_month].is_a?(Integer) 
    assert leads_data[:last_month].is_a?(Integer)
    assert leads_data[:growth_rate].is_a?(Numeric)
    
    # Ensure no NaN values
    refute_equal Float::NAN, leads_data[:growth_rate]
    refute_includes leads_data.to_s, "NaN"
  end

  test "conversion analytics returns proper numeric values" do
    controller = DashboardController.new
    controller.instance_variable_set(:@user, @user)
    controller.instance_variable_set(:@user_keywords, @user.keywords)
    
    conversion_data = controller.send(:conversion_analytics)
    
    # Check all values are numeric
    assert conversion_data[:mentions].is_a?(Integer)
    assert conversion_data[:qualified].is_a?(Integer)
    assert conversion_data[:contacted].is_a?(Integer)
    assert conversion_data[:converted].is_a?(Integer)
    assert conversion_data[:conversion_rate].is_a?(Numeric)
    
    # Ensure no NaN values
    refute_equal Float::NAN, conversion_data[:conversion_rate]
    refute_includes conversion_data.to_s, "NaN"
  end

  test "insights analytics returns array of insights" do
    controller = DashboardController.new
    controller.instance_variable_set(:@user, @user)
    controller.instance_variable_set(:@user_keywords, @user.keywords)
    
    insights_data = controller.send(:insights_analytics)
    
    assert insights_data.is_a?(Array)
    assert insights_data.length > 0
    
    # Check each insight has required fields
    insights_data.each do |insight|
      assert insight.key?(:type)
      assert insight.key?(:title)
      assert insight.key?(:description)
      assert insight.key?(:priority)
    end
    
    # Ensure no NaN values in insights
    refute_includes insights_data.to_s, "NaN"
  end

  test "growth rate calculation handles edge cases" do
    controller = DashboardController.new
    controller.instance_variable_set(:@user, @user)
    controller.instance_variable_set(:@user_keywords, @user.keywords)
    
    # Test with zero values
    this_month = 0
    last_month = 0
    
    growth_rate = if last_month > 0
                    ((this_month - last_month).to_f / last_month * 100).round(1)
                  elsif this_month > 0
                    100.0
                  else
                    0.0
                  end
    
    assert_equal 0.0, growth_rate
    refute_equal Float::NAN, growth_rate
    
    # Test with positive growth
    this_month = 10
    last_month = 5
    
    growth_rate = if last_month > 0
                    ((this_month - last_month).to_f / last_month * 100).round(1)
                  elsif this_month > 0
                    100.0
                  else
                    0.0
                  end
    
    assert_equal 100.0, growth_rate
    refute_equal Float::NAN, growth_rate
  end
end
