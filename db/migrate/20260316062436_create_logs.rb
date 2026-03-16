class CreateLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :logs do |t|
      t.references :picture, null: false, foreign_key: true
      t.datetime :posted_at
      t.integer :posted_order

      t.timestamps
    end
  end
end
