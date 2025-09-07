class Lead < ApplicationRecord
  self.inheritance_column = nil # Disable single-table inheritance

  belongs_to :mention
  has_one :keyword, through: :mention
  has_one :user, through: :keyword

  # Validations
  validates :status, inclusion: { in: %w[new contacted converted rejected] }

  # Scopes
  scope :new_leads, -> { where(status: "new") }
  scope :contacted, -> { where(status: "contacted") }
  scope :converted, -> { where(status: "converted") }
  scope :rejected, -> { where(status: "rejected") }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def contacted?
    last_contacted_at.present?
  end

  def converted?
    status == "converted"
  end

  def response_time_hours
    return nil unless last_contacted_at && created_at
    ((last_contacted_at - created_at) / 1.hour).round(2)
  end
end
