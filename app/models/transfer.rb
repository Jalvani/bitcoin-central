class Transfer < ActiveRecord::Base
  MIN_BTC_CONFIRMATIONS = 5

  default_scope order('created_at DESC')

  after_create :execute,
    :inactivate_orders

  belongs_to :user

  validates :user,
    :presence => true

  validates :amount,
    :presence => true,
    :numericality => true,
    :user_balance => true,
    :minimal_amount => true

  validates :currency,
    :presence => true

#  validate :user do
#    if self.class == Transfer
#      errors[:base] << "You must provide a payee"
#    end
#  end

  def type_name
    type.gsub(/Transfer/, "").underscore.gsub(/\_/, " ").titleize
  end

  def withdrawal!
    self.amount = -(amount.abs) if amount
    self
  end

  # Placeholder
  def confirmed?
    true
  end

  def execute
  end

  def inactivate_orders
    user.reload.trade_orders.each { |t| t.inactivate_if_needed! }
  end

  scope :with_currency, lambda { |currency|
    where("transfers.currency = ?", currency.to_s.upcase)
  }

  scope :with_confirmations, lambda { |unconfirmed|
    unless unconfirmed
      where("currency <> 'BTC' OR bt_tx_confirmations >= ? OR amount <= 0 OR bt_tx_id IS NULL", MIN_BTC_CONFIRMATIONS)
    end
  }

  def self.from_params(payee, params)
    transfer = Transfer.new

    if payee
      if payee =~ /^BC-[A-Z][0-9]{6}$/
        transfer = InternalTransfer.new(params)
        transfer.payee = User.find_by_account(payee)
      elsif Bitcoin::Util.valid_bitcoin_address?(payee)
        transfer = BitcoinTransfer.new(params)
        transfer.address = payee
      elsif payee =~ /^U[0-9]{7}$/
        transfer = LibertyReserveTransfer.new(params)
        transfer.lr_account_id = payee
      end

      transfer.withdrawal!
    end
  end
end