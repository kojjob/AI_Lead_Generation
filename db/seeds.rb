# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Clear existing data in development
if Rails.env.development?
  puts "Clearing existing data..."
  Lead.destroy_all
  Mention.destroy_all
  Keyword.destroy_all
  Integration.destroy_all
  User.destroy_all
end

puts "Creating sample data for dashboard..."

# Create a sample user
user = User.create!(
  email: 'demo@example.com',
  password: 'password',
  password_confirmation: 'password',
  first_name: 'Demo',
  last_name: 'User',
  company: 'AI Lead Gen Co',
  job_title: 'Marketing Director'
)

puts "Created user: #{user.email}"

# Create sample keywords
keywords = [
  'Ruby on Rails developer',
  'React developer needed',
  'AI automation consultant',
  'SaaS marketing help',
  'Lead generation services'
]

created_keywords = keywords.map do |keyword_text|
  keyword = user.keywords.create!(
    keyword: keyword_text,
    platform: 'twitter',
    active: true,
    status: 'active'
  )
  puts "Created keyword: #{keyword.keyword}"
  keyword
end

# Create sample integrations
integrations = [
  { provider: 'Twitter', status: 'active' },
  { provider: 'LinkedIn', status: 'active' },
  { provider: 'Reddit', status: 'inactive' }
]

created_integrations = integrations.map do |integration_data|
  integration = user.integrations.create!(
    provider: integration_data[:provider],
    status: integration_data[:status],
    credentials: { api_key: 'sample_key_123' },
    last_searched_at: rand(1..7).days.ago
  )
  puts "Created integration: #{integration.provider}"
  integration
end

# Create sample mentions for each keyword
created_keywords.each do |keyword|
  # Create 5-15 mentions per keyword
  mention_count = rand(5..15)

  mention_count.times do |i|
    mention = keyword.mentions.create!(
      content: "Looking for help with #{keyword.keyword.downcase}. Anyone have recommendations?",
      author: "user_#{rand(1000..9999)}",
      posted_at: rand(30.days).seconds.ago,
      engagement_score: rand(0.1..1.0).round(2),  # Add engagement_score
      raw_payload: {
        id: "mention_#{rand(100000..999999)}",
        platform: [ 'twitter', 'linkedin', 'reddit' ].sample,
        engagement: rand(1..100)
      },
      status: 'active'
    )

    # Create leads for some mentions (30-50% conversion rate)
    if rand < 0.4
      lead_status = [ 'new', 'contacted', 'converted', 'rejected' ].sample
      contacted_at = lead_status.in?([ 'contacted', 'converted' ]) ? rand(1..5).days.ago : nil

      lead = Lead.create!(
        user: user,  # Add user association
        mention: mention,
        priority_score: rand(0.1..1.0).round(2),
        status: lead_status,
        last_contacted_at: contacted_at,
        notes: "Generated from #{mention.author}'s mention about #{keyword.keyword}",
        tags: [ 'social_media', 'inbound' ].sample(rand(1..2))
      )
    end
  end

  puts "Created #{mention_count} mentions for keyword: #{keyword.keyword}"
end

# Update some leads to have recent activity
recent_leads = Lead.limit(5)
recent_leads.each_with_index do |lead, index|
  lead.update!(
    last_contacted_at: (index + 1).hours.ago,
    status: [ 'contacted', 'converted' ].sample
  )
end

puts "\nSample data created successfully!"
puts "Dashboard data summary:"
puts "- Users: #{User.count}"
puts "- Keywords: #{Keyword.count}"
puts "- Integrations: #{Integration.count}"
puts "- Mentions: #{Mention.count}"
puts "- Leads: #{Lead.count}"
puts "- Converted leads: #{Lead.where(status: 'converted').count}"
puts "\nYou can now visit the dashboard at http://localhost:3001/dashboard"
puts "Login with: demo@example.com / password"
