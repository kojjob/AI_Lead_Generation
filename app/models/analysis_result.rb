class AnalysisResult < ApplicationRecord
  self.inheritance_column = nil # Disable single-table inheritance

  belongs_to :mention
end
