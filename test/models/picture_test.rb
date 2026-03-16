require "test_helper"

class PictureTest < ActiveSupport::TestCase
  setup do
    Log.delete_all
    Picture.delete_all
  end

  # === Validations ===

  test "valid with required attributes" do
    pic = Picture.new(s3_key: "photos/test.jpg", alt_text: "A sunset", hashtags: "#sunset")
    assert pic.valid?
  end

  test "invalid without s3_key" do
    pic = Picture.new(s3_key: nil)
    assert_not pic.valid?
    assert_includes pic.errors[:s3_key], "can't be blank"
  end

  test "order must be unique" do
    Picture.create!(s3_key: "photos/a.jpg", order: 1)
    pic = Picture.new(s3_key: "photos/b.jpg", order: 1)
    assert_not pic.valid?
    assert_includes pic.errors[:order], "has already been taken"
  end

  # === Auto-assign order on create ===

  test "auto-assigns order on create when not specified" do
    p1 = Picture.create!(s3_key: "photos/a.jpg")
    assert_equal 1, p1.order

    p2 = Picture.create!(s3_key: "photos/b.jpg")
    assert_equal 2, p2.order

    p3 = Picture.create!(s3_key: "photos/c.jpg")
    assert_equal 3, p3.order
  end

  test "auto-assigns order 1 when table is empty" do
    pic = Picture.create!(s3_key: "photos/first.jpg")
    assert_equal 1, pic.order
  end

  # === Reorder ===

  test "reorder_to moves picture forward" do
    p1 = Picture.create!(s3_key: "photos/a.jpg")
    p2 = Picture.create!(s3_key: "photos/b.jpg")
    p3 = Picture.create!(s3_key: "photos/c.jpg")
    p4 = Picture.create!(s3_key: "photos/d.jpg")

    # Move p1 (order 1) to position 3
    p1.reorder_to(3)

    assert_equal 3, p1.reload.order
    assert_equal 1, p2.reload.order
    assert_equal 2, p3.reload.order
    assert_equal 4, p4.reload.order
  end

  test "reorder_to moves picture backward" do
    p1 = Picture.create!(s3_key: "photos/a.jpg")
    p2 = Picture.create!(s3_key: "photos/b.jpg")
    p3 = Picture.create!(s3_key: "photos/c.jpg")
    p4 = Picture.create!(s3_key: "photos/d.jpg")

    # Move p4 (order 4) to position 2
    p4.reorder_to(2)

    assert_equal 1, p1.reload.order
    assert_equal 3, p2.reload.order
    assert_equal 4, p3.reload.order
    assert_equal 2, p4.reload.order
  end

  test "reorder_to same position is a no-op" do
    p1 = Picture.create!(s3_key: "photos/a.jpg")
    p2 = Picture.create!(s3_key: "photos/b.jpg")

    p1.reorder_to(1)
    assert_equal 1, p1.reload.order
    assert_equal 2, p2.reload.order
  end

  # === Delete compaction ===

  test "destroying a picture compacts orders" do
    p1 = Picture.create!(s3_key: "photos/a.jpg")
    p2 = Picture.create!(s3_key: "photos/b.jpg")
    p3 = Picture.create!(s3_key: "photos/c.jpg")
    p4 = Picture.create!(s3_key: "photos/d.jpg")

    p2.destroy!

    assert_equal 1, p1.reload.order
    assert_equal 2, p3.reload.order
    assert_equal 3, p4.reload.order
  end

  test "destroying last picture works" do
    p1 = Picture.create!(s3_key: "photos/a.jpg")
    p1.destroy!
    assert_equal 0, Picture.count
  end

  # === Gapless invariant ===

  test "max order equals count after various operations" do
    Picture.create!(s3_key: "photos/a.jpg")
    Picture.create!(s3_key: "photos/b.jpg")
    Picture.create!(s3_key: "photos/c.jpg")
    assert_equal Picture.count, Picture.maximum(:order)

    Picture.find_by(order: 2).destroy!
    assert_equal Picture.count, Picture.maximum(:order)

    p = Picture.first
    p.reorder_to(Picture.count)
    assert_equal Picture.count, Picture.maximum(:order)
  end
end
