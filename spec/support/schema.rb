ActiveRecord::Schema.define do
  self.verbose = false

  create_table :articles, :force => true do |t|
    t.string :status
    t.string :type
    t.string :heading
    t.text :text
    t.deleted_at :datetime

    t.timestamps
  end
end
