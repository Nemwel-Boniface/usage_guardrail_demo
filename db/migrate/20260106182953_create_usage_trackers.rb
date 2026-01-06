class CreateUsageTrackers < ActiveRecord::Migration[8.1]
  def change
    create_table :usage_trackers do |t|
      t.date    :month,         null: false
      t.integer :request_count, null: false, default: 0
      t.integer :request_limit, null: false
      t.boolean :locked,        null: false, default: false

      t.timestamps
    end

    add_index :usage_trackers, :month, unique: true
  end
end
