# frozen_string_literal: true

class ApiKey < ApplicationRecord
  belongs_to :user
  
  before_create :generate_token
  
  validates :name, presence: true
  validates :token, uniqueness: true
  
  scope :active, -> { where(active: true) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  
  def expired?
    expires_at.present? && expires_at < Time.current
  end
  
  def valid_token?
    active? && !expired?
  end
  
  def regenerate_token!
    generate_token
    save!
  end
  
  def deactivate!
    update!(active: false)
  end
  
  def activate!
    update!(active: true)
  end
  
  # Track API usage
  def record_usage!
    increment!(:usage_count)
    update!(last_used_at: Time.current)
  end
  
  private
  
  def generate_token
    loop do
      self.token = SecureRandom.hex(32)
      break unless ApiKey.exists?(token: token)
    end
  end
end