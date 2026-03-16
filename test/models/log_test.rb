require "test_helper"

class LogTest < ActiveSupport::TestCase
  setup do
    Log.delete_all
    Picture.delete_all
  end

  test "belongs to picture" do
    pic = Picture.create!(s3_key: "photos/a.jpg", order: 1)
    log = Log.create!(picture: pic, posted_at: Time.current, posted_order: 1)
    assert_equal pic, log.picture
  end

  test "validates presence of posted_at" do
    pic = Picture.create!(s3_key: "photos/a.jpg", order: 1)
    log = Log.new(picture: pic, posted_order: 1)
    assert_not log.valid?
    assert_includes log.errors[:posted_at], "can't be blank"
  end

  test "validates presence of posted_order" do
    pic = Picture.create!(s3_key: "photos/a.jpg", order: 1)
    log = Log.new(picture: pic, posted_at: Time.current)
    assert_not log.valid?
    assert_includes log.errors[:posted_order], "can't be blank"
  end

  # === next_scheduled_order ===

  test "next_scheduled_order returns 1 when no logs exist" do
    assert_equal 1, Log.next_scheduled_order
  end

  test "next_scheduled_order returns last posted order + 1" do
    p1 = Picture.create!(s3_key: "photos/a.jpg", order: 1)
    p2 = Picture.create!(s3_key: "photos/b.jpg", order: 2)
    p3 = Picture.create!(s3_key: "photos/c.jpg", order: 3)

    Log.create!(picture: p1, posted_at: 2.days.ago, posted_order: 1)
    Log.create!(picture: p2, posted_at: 1.day.ago, posted_order: 2)

    assert_equal 3, Log.next_scheduled_order
  end

  test "next_scheduled_order wraps to 1 when past last picture" do
    p1 = Picture.create!(s3_key: "photos/a.jpg", order: 1)
    p2 = Picture.create!(s3_key: "photos/b.jpg", order: 2)

    Log.create!(picture: p2, posted_at: Time.current, posted_order: 2)

    # Next would be 3, but only 2 pictures exist, so wrap to 1
    next_order = Log.next_scheduled_order
    assert_equal 1, next_order
  end

  test "next_scheduled_order wraps when exact next order has no picture" do
    p1 = Picture.create!(s3_key: "photos/a.jpg", order: 1)
    p2 = Picture.create!(s3_key: "photos/b.jpg", order: 2)
    p3 = Picture.create!(s3_key: "photos/c.jpg", order: 3)

    Log.create!(picture: p3, posted_at: Time.current, posted_order: 3)

    assert_equal 1, Log.next_scheduled_order
  end
end
