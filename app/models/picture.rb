class Picture < ApplicationRecord
  validates :s3_key, presence: true
  validates :order, uniqueness: true

  before_create :assign_order
  after_destroy :compact_orders

  def reorder_to(new_position)
    return if new_position == order

    Picture.transaction do
      old_position = order
      # Use negative id as temp slot to avoid unique constraint during shift
      temp_order = -id
      update_column(:order, temp_order)

      if new_position > old_position
        # Moving forward: shift pictures between old+1..new down by 1
        Picture.where(order: (old_position + 1)..new_position)
               .update_all("\"order\" = \"order\" - 1")
      else
        # Moving backward: shift in descending order to avoid unique constraint
        Picture.where(order: new_position..(old_position - 1))
               .order(order: :desc)
               .each { |p| p.update_column(:order, p.order + 1) }
      end

      update_column(:order, new_position)
    end
  end

  private

  def assign_order
    self.order = (Picture.maximum(:order) || 0) + 1
  end

  def compact_orders
    Picture.where("\"order\" > ?", order)
           .update_all("\"order\" = \"order\" - 1")
  end
end
