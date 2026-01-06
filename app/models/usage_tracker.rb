class UsageTracker < ApplicationRecord
  validates :month, presence: true, uniqueness: true
end
