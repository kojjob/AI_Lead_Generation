class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :keywords, dependent: :destroy
  has_many :integrations, dependent: :destroy
  has_many :mentions, through: :keywords
  has_many :leads, through: :mentions

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :first_name, :last_name, length: { maximum: 50 }

  # Scopes
  scope :active, -> { where(active: true) }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name.present? ? full_name : email.split("@").first.humanize
  end

  def active_integrations
    integrations.where(status: "active")
  end

  def recent_leads(limit = 10)
    leads.includes(:mention, :keyword).order(created_at: :desc).limit(limit)
  end

  def conversion_rate
    return 0 if mentions.count.zero?
    (leads.where(status: "converted").count.to_f / mentions.count * 100).round(2)
  end
end
