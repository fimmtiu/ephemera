class Log < ApplicationRecord
  belongs_to :picture

  validates :posted_at, presence: true
  validates :posted_order, presence: true

  def self.next_scheduled_order
    last_log = order(posted_at: :desc).first
    return 1 unless last_log

    next_order = last_log.posted_order + 1

    if Picture.exists?(order: next_order)
      next_order
    else
      1
    end
  end
end
