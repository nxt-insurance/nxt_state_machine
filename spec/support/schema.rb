ActiveRecord::Schema.define do
  self.verbose = false

  create_table :articles, :force => true do |t|
    t.string :status
    t.timestamps
  end
end
