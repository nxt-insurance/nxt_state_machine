ActiveRecord::Schema.define do
  self.verbose = false

  create_table :articles, :force => true do |t|
    t.string :status
    t.string :type
    t.string :headline
    t.text :text
    t.datetime :deleted_at

    t.timestamps
  end
end
