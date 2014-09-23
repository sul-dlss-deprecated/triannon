class CreateTriannonAnnotations < ActiveRecord::Migration
  def change
    create_table :triannon_annotations do |t|
      t.text :data

      t.timestamps null: false
    end
  end
end
