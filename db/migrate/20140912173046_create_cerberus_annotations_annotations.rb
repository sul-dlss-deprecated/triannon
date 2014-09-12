class CreateCerberusAnnotationsAnnotations < ActiveRecord::Migration
  def change
    create_table :cerberus_annotations_annotations do |t|
      t.text :data

      t.timestamps null: false
    end
  end
end
