require 'grape'
require 'sequel'
require 'bcrypt'
require 'unicode_utils'

require_relative 'common'
require_relative 'helpers'

module Banking
  module DB
    # This class only contains routes that collect and return data.
    class Return < Grape::API
      format :json

      helpers Banking::DB::Helpers

      # Holds the DB connector instance for use in this class.
      DB = Banking::DB::Common.db_instance

      # Log in route
      # Make sure that username exists, that the user is logging
      # in from an allowed device, and that the password is correct
      post :login do
        data = DB[:Customer].where(UserID: params[:username]).first
        if data.nil?
          { auth: false }
        else
          pw = BCrypt::Password.new(data[:Password])
          if pw == params[:password] &&
             device_allowed?(params[:username], params[:dev_id])
            token = create_token(params[:username], params[:dev_id])
            { auth: true, name: formatted_name(data), token: token }
          else
            { auth: false }
          end
        end
      end

      # Return list of transactions.
      # Checks token is valid, then gets transactions and returns the
      # set of 50 based on the page number given.
      post :transactions do
        if authenticate?(params[:token])
          update_token(params[:token])
          data = DB[:Transactions].select(:Date, :Change, :Balance, :Desc)
                 .where(AcctNo: params[:acct_no]).order(Sequel.desc(:Date))
                 .limit(50, (params[:page].to_i - 1) * 50).all
          if params[:count].nil?
            count = DB[:Transactions].where(AcctNo: params[:acct_no]).count
            { auth: true, transactions: data, count: count }
          else
            { auth: true, transactions: data }
          end
        else
          { auth: false }
        end
      end

      # Return list of payees
      # Checks token is valid, then gets the user_id from the token, and
      # uses that to get the list of payees valid for the user.
      post :payees do
        if authenticate?(params[:token])
          update_token(params[:token])
          user_id = user_id_from_token(params[:token])
          accs_available = DB[:Payee].select(:AccTo, :IDTo)
                           .where(IDFrom: user_id).all
          accs_available.each do |acc|
            payee = DB[:Customer].where(UserID: acc[:IDTo]).first
            acc['Payee'] = formatted_name(payee)
          end
          { auth: true, payees: accs_available }
        else
          { auth: false }
        end
      end

      # Return list of accounts
      # Checks token is valid, gets the user_id from the token, and
      # uses that to get the list of accounts belonging to that user.
      post :accounts do
        if authenticate?(params[:token])
          update_token(params[:token])
          user_id = user_id_from_token(params[:token])
          data = DB[:Account].select(:AcctNo, :AcctType, :SortCode, :Balance)
                 .where(UserID: user_id).all
          { auth: true, accounts: data }
        else
          { auth: false }
        end
      end
    end
  end
end
