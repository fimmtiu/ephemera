class CreatePictures < ActiveRecord::Migration[8.1]
  def change
    create_table :pictures do |t|
      t.string :s3_key, null: false
      t.text :alt_text
      t.text :hashtags
      t.string :sensitive_content
      t.integer :order, null: false
      t.string :original_filename
      t.string :content_type

      t.timestamps
    end

    add_index :pictures, :order, unique: true
  end
end
