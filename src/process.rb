require 'grape'
require 'sequel'
require 'securerandom'

require_relative 'helpers'
require_relative 'common'

module Banking
  module DB
    # This class contains routes that modify the database,
    # except creating and updating tokens, which remains
    # in the return class.
    class Process < Grape::API
      format :json

      helpers Banking::DB::Helpers

      # Holds the instance of the DB connector for use in this class
      DB = Banking::DB::Common.db_instance

      # Transfer money from one account to another belonging to the
      # same user.
      # Does the usual token-checking stuff, then determines if the
      # account the money is coming from belongs to the same user as
      # the token, then checks the account the money is going to
      # belongs to the same account, then checks there's enough
      # money to move, and then goes ahead and does it.
      post :transfer do
        if authenticate?(params[:token])
          id_from = user_id_from_token(params[:token])
          case
          when !account_belongs_to?(id_from, params[:acct_no])
            { auth: true, success: false, reason: 'user' }
          when !valid_transfer?(id_from, params[:acct_to])
            { auth: true, success: false, reason: 'account' }
          when !payment_allowed?(params[:acct_no], params[:amount])
            { auth: true, success: false, reason: 'balance' }
          else
            # Get details to use in transactions
            from_acc = DB[:Account].where(AcctNo: params[:acct_no]).first
            to_acc = DB[:Account].where(AcctNo: params[:acct_to]).first
            cur_balance = from_acc[:Balance] * 100
            to_cur_balance = to_acc[:Balance] * 100
            name = formatted_name(DB[:Customer]
                   .where(UserID: from_acc[:UserID]).first)
            sort_code = from_acc[:SortCode]
            # This updates, in order:
            #  -The account the money is leaving
            #  -The transaction with the money leaving the account
            #  -The transaction with the money entering the second account
            #  -The account the money is going into
            DB[:Account].where(AcctNo: params[:acct_no])
              .update(Balance: (cur_balance - params[:amount].to_i).fdiv(100))
            DB[:Transactions].insert(ID: SecureRandom.uuid,
                                     AcctNo: params[:acct_no],
                                     Date: Time.now.to_i,
                                     Change: (params[:amount].to_i * -1)
                                             .fdiv(100),
                                     Balance: (cur_balance - params[:amount]
                                              .to_i).fdiv(100),
                                     Desc: name + ' ' << params[:acct_to] <<
                                           ' ' << sort_code)
            DB[:Transactions].insert(ID: SecureRandom.uuid,
                                     AcctNo: params[:acct_to],
                                     Date: Time.now.to_i,
                                     Change: params[:amount].to_i.fdiv(100),
                                     Balance: (to_cur_balance +
                                               params[:amount]
                                              .to_i).fdiv(100),
                                     Desc: name + ' ' << params[:acct_no] <<
                                           ' ' << sort_code)
            DB[:Account].where(AcctNo: params[:acct_to])
              .update(Balance: (to_cur_balance + params[:amount].to_i)
              .fdiv(100))
            { auth: true, success: true }
          end
        else
          { auth: false }
        end
      end

      # Make a payment from one account to another belonging to a
      # different user.
      # Does the usual token-checking stuff, then determines if the
      # account the money is going to is a valid payee for that user,
      # then checks there's enough money to move, and then goes ahead
      # and does it.
      post :payment do
        if authenticate?(params[:token])
          id_from = user_id_from_token(params[:token])
          if account_belongs_to?(id_from, params[:acct_to])
            if valid_payee?(id_from, params[:acct_to])
              if payment_allowed?(params[:acct_no], params[:amount])
                from_acc = DB[:Account].where(AcctNo: params[:acct_no]).first
                to_acc = DB[:Account].where(AcctNo: params[:acct_to]).first
                cur_balance = DB[:Account].where(AcctNo: params[:acct_no])
                              .first[:Balance] * 100
                to_cur_balance = DB[:Account].where(AcctNo: params[:acct_to])
                                 .first[:Balance] * 100

                # This updates, in order:
                #  -The account the money is leaving
                #  -The transaction with the money leaving the account
                #  -The transaction with the money entering the second account
                #  -The account the money is going into
                DB[:Account].where(AcctNo: params[:acct_no])
                  .update(Balance: (cur_balance - params[:amount].to_i).fdiv(100))
                DB[:Transactions].insert(ID: SecureRandom.uuid,
                                         AcctNo: params[:acct_no],
                                         Date: Time.now.to_i,
                                         Change: (params[:amount].to_i * -1)
                                                 .fdiv(100),
                                         Balance: (cur_balance - params[:amount]
                                                  .to_i).fdiv(100),
                                         Desc: params[:reference] + ' ' <<
                                               params[:acct_to] << ' ' <<
                                               to_acc[:SortCode])
                DB[:Transactions].insert(ID: SecureRandom.uuid,
                                         AcctNo: params[:acct_to],
                                         Date: Time.now.to_i,
                                         Change: params[:amount].to_i.fdiv(100),
                                         Balance: (to_cur_balance +
                                                  params[:amount]
                                                  .to_i).fdiv(100),
                                         Desc: params[:reference] + ' ' <<
                                               params[:acct_no] << ' ' <<
                                               from_acc[:SortCode])
                DB[:Account].where(AcctNo: params[:acct_to])
                  .update(Balance: (to_cur_balance + params[:amount].to_i)
                  .fdiv(100))
                { auth: true, success: true }
              else
                { auth: true, success: false, reason: 'balance' }
              end
            else
              { auth: true, success: false, reason: 'payee' }
            end
          else
            { auth: true, success: false, reason: 'user' }
          end
        else
          { auth: false }
        end
      end
    end
  end
end
