class Mention < ApplicationRecord
  self.inheritance_column = nil # Disable single-table inheritance

  belongs_to :keyword
  has_one :user, through: :keyword
  has_many :leads, dependent: :destroy

  # Validations
  validates :content, presence: true
  # Note: platform column doesn't exist in current schema

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :qualified, -> { joins(:leads) }

  # Instance methods
  def qualified?
    leads.any?
  end

  def platform_icon
    # Default icon since platform column doesn't exist
    "link"
  end
end
