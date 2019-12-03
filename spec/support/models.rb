require_relative 'article_workflow'

class Article < ActiveRecord::Base
  TYPES = %w[manual_approval auto_approval]
  self.inheritance_column = nil

  validates :status, presence: true
  validates_inclusion_of :type, in: TYPES
  validates :headline, presence: true, if: -> { status.in?(%w[approved published]) }
end

class Application < ActiveRecord::Base
  validates :content, presence: true
  validates :status, presence: true
  validates :received_at, presence: true
  validates :processed_at, presence: true, if: -> { status == 'processed' }
  validates :rejected_at, presence: true, if: -> { status == 'rejected' }
  validates :accepted_at, presence: true, if: -> { status == 'accepted' }
end

class ApplicationWithStateMachine < Application
  include NxtStateMachine::ActiveRecord
end
