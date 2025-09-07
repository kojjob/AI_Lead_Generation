class WebhooksController < ApplicationController
  # Skip CSRF protection for webhook endpoints
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  
  before_action :verify_webhook_signature, except: [:index]
  before_action :set_integration, except: [:index]

  # GET /webhooks - Admin interface for webhook management
  def index
    authenticate_user!
    @webhooks = current_user.integrations.joins(:webhooks)
                           .includes(:webhooks)
                           .flat_map(&:webhooks)
                           .sort_by(&:created_at)
                           .reverse
                           .first(100)
  end

  # POST /webhooks/:platform/:integration_id
  def receive
    webhook_data = {
      integration: @integration,
      event_type: determine_event_type,
      payload: request.body.read,
      signature: request.headers['X-Hub-Signature'] || request.headers['X-Signature'],
      source_ip: request.remote_ip,
      user_agent: request.user_agent,
      headers: extract_relevant_headers
    }

    webhook = Webhook.create!(webhook_data)
    
    # Process immediately in development, queue in production
    if Rails.env.development?
      webhook.process!
    else
      WebhookProcessorJob.perform_later(webhook)
    end

    render json: { status: 'received', webhook_id: webhook.id }, status: :ok
  rescue StandardError => e
    Rails.logger.error "Webhook processing error: #{e.message}"
    render json: { error: 'Webhook processing failed' }, status: :unprocessable_entity
  end

  # POST /webhooks/instagram/:integration_id
  def instagram
    process_platform_webhook('instagram')
  end

  # POST /webhooks/tiktok/:integration_id
  def tiktok
    process_platform_webhook('tiktok')
  end

  # POST /webhooks/salesforce/:integration_id
  def salesforce
    process_platform_webhook('salesforce')
  end

  # POST /webhooks/hubspot/:integration_id
  def hubspot
    process_platform_webhook('hubspot')
  end

  # POST /webhooks/pipedrive/:integration_id
  def pipedrive
    process_platform_webhook('pipedrive')
  end

  # GET /webhooks/:platform/:integration_id/verify - Webhook verification endpoint
  def verify
    challenge = params['hub.challenge'] || params['challenge']
    verify_token = params['hub.verify_token'] || params['verify_token']
    
    if verify_token == @integration.webhook_secret
      render plain: challenge, status: :ok
    else
      render json: { error: 'Invalid verify token' }, status: :forbidden
    end
  end

  private

  def set_integration
    @integration = Integration.find(params[:integration_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Integration not found' }, status: :not_found
  end

  def verify_webhook_signature
    return true if Rails.env.development? # Skip verification in development
    
    signature = request.headers['X-Hub-Signature'] || 
                request.headers['X-Signature'] ||
                request.headers['X-Shopify-Hmac-Sha256']
    
    return render_unauthorized unless signature
    
    payload = request.body.read
    expected_signature = generate_signature(payload, @integration&.webhook_secret)
    
    unless secure_compare(signature, expected_signature)
      Rails.logger.warn "Invalid webhook signature for integration #{@integration&.id}"
      render_unauthorized
    end
  end

  def generate_signature(payload, secret)
    return nil unless secret
    
    case params[:platform]
    when 'instagram', 'facebook'
      "sha1=#{OpenSSL::HMAC.hexdigest('sha1', secret, payload)}"
    when 'tiktok'
      "sha256=#{OpenSSL::HMAC.hexdigest('sha256', secret, payload)}"
    when 'salesforce'
      Base64.encode64(OpenSSL::HMAC.digest('sha256', secret, payload)).strip
    when 'hubspot'
      "sha256=#{OpenSSL::HMAC.hexdigest('sha256', secret, payload)}"
    when 'pipedrive'
      OpenSSL::HMAC.hexdigest('sha1', secret, payload)
    else
      "sha256=#{OpenSSL::HMAC.hexdigest('sha256', secret, payload)}"
    end
  end

  def secure_compare(a, b)
    return false if a.nil? || b.nil? || a.length != b.length
    
    result = 0
    a.bytes.zip(b.bytes) { |x, y| result |= x ^ y }
    result == 0
  end

  def render_unauthorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end

  def determine_event_type
    case params[:platform]
    when 'instagram'
      determine_instagram_event_type
    when 'tiktok'
      determine_tiktok_event_type
    when 'salesforce'
      determine_salesforce_event_type
    when 'hubspot'
      determine_hubspot_event_type
    when 'pipedrive'
      determine_pipedrive_event_type
    else
      'unknown'
    end
  end

  def determine_instagram_event_type
    # Instagram webhook event type determination
    parsed_body = JSON.parse(request.body.read) rescue {}
    
    if parsed_body['object'] == 'instagram'
      entry = parsed_body['entry']&.first
      changes = entry&.dig('changes')&.first
      
      case changes&.dig('field')
      when 'mentions'
        'mentions'
      when 'comments'
        'comments'
      when 'story_insights'
        'stories'
      else
        'unknown'
      end
    else
      'unknown'
    end
  end

  def determine_tiktok_event_type
    # TikTok webhook event type determination
    parsed_body = JSON.parse(request.body.read) rescue {}
    
    case parsed_body['type']
    when 'mention'
      'mentions'
    when 'comment'
      'comments'
    when 'video'
      'videos'
    else
      'unknown'
    end
  end

  def determine_salesforce_event_type
    # Salesforce webhook event type determination
    parsed_body = JSON.parse(request.body.read) rescue {}
    
    case parsed_body['sobject']
    when 'Lead'
      parsed_body['event_type'] || 'lead_updated'
    when 'Contact'
      'contact_updated'
    else
      'unknown'
    end
  end

  def determine_hubspot_event_type
    # HubSpot webhook event type determination
    parsed_body = JSON.parse(request.body.read) rescue {}
    
    subscription_type = parsed_body.dig(0, 'subscriptionType')
    
    case subscription_type
    when 'contact.creation'
      'contact_created'
    when 'contact.propertyChange'
      'contact_updated'
    when 'deal.creation'
      'deal_created'
    else
      'unknown'
    end
  end

  def determine_pipedrive_event_type
    # Pipedrive webhook event type determination
    parsed_body = JSON.parse(request.body.read) rescue {}
    
    event = parsed_body['event']
    object_type = parsed_body['meta']&.dig('object')
    
    case object_type
    when 'person'
      event == 'added' ? 'person_added' : 'person_updated'
    when 'deal'
      'deal_added'
    else
      'unknown'
    end
  end

  def extract_relevant_headers
    relevant_headers = %w[
      X-Hub-Signature X-Signature X-Shopify-Hmac-Sha256
      X-GitHub-Event X-GitHub-Delivery
      User-Agent Content-Type
    ]
    
    headers = {}
    relevant_headers.each do |header|
      value = request.headers[header]
      headers[header] = value if value.present?
    end
    
    headers
  end

  def process_platform_webhook(platform)
    unless @integration.platform_name == platform
      return render json: { error: 'Platform mismatch' }, status: :bad_request
    end
    
    receive
  end
end
