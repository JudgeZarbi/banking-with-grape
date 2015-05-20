require 'unicode_utils'
require 'securerandom'
require 'grape'
require_relative 'common'
module Banking
  module DB
    # Class containing all the helpers used by
    # the REST API.
    module Helpers
      # Holds the DB instance for use in this class.
      DB = Banking::DB::Common.db_instance

      # Processes the user's name into a neater form
      # of the format:
      #
      # Title Initials Surname
      #
      # e.g. Mr A.N. Other
      def formatted_name(data)
        '' << data[:Title] << ' ' <<
          initials(data[:"First Names"]) <<
          data[:Surname]
      end

      # Converts the user's first names into initial
      # form. Uses UnicodeUtils to allow proper conversion
      # of Unicode/UTF-8 characters.
      def initials(names)
        split_names = names.split(' ')
        initials = ''
        split_names.each do |name|
          initials << name[0].chr << '. '
        end
        UnicodeUtils.upcase(initials)
      end

      # Authenticates the user by determining firstly
      # whether the token exists, and if it does, whether
      # the token has passed its end of life of 10 minutes
      # after the last activity.
      def authenticate?(token)
        data = DB[:Token].where(Token: token).first
        unless data.nil?
          if data[:Token] == token && data[:Timestamp] >= Time.now.to_i
            return true
          end
        end
        false
      end

      # Determines whether the device is allowed on login
      # by comparing each device ID (UUID form) available
      # to the user with the device ID reported by the
      # connecting device.
      def device_allowed?(user_id, dev_id)
        data = DB[:Token].select(:DeviceID).where(UserID: user_id).all
        data.each do |item|
          return true if item[:DeviceID] == dev_id
        end
        false
      end

      # Creates a token (512 base64 characters) belonging
      # to a specific user-device combination and gives
      # it a 10 minute lifespan
      def create_token(user_id, dev_id)
        token = SecureRandom.base64(384)
        DB[:Token].where(UserID: user_id).where(DeviceID: dev_id)
          .update(Token: token, Timestamp: Time.now.to_i + 600)
        token
      end

      # Update the token's lifespan to 10 minutes when
      # an action has been performed.
      def update_token(token)
        DB[:Token].where(Token: token).update(Timestamp: Time.now.to_i + 600)
      end

      # Determine whether a particular account is a valid
      # payment target for a particular user.
      def valid_payee?(id_from, acc_to)
        if DB[:Payee].where(IDFrom: id_from).where(AccTo: acc_to).count == 0
          return false
        end
        true
      end

      # Determine whether a particular account belongs to
      # the same user as the account selected.
      def valid_transfer?(id_from, acc_to)
        user_accs =  DB[:Account].where(UserID: id_from).all
        user_accs.each do |acc|
          puts(acc[:AcctNo])
          puts(acc_to)
          puts(acc[:AcctNo] == acc_to)
          return true if acc[:AcctNo] == acc_to
        end
        false
      end

      # Determine whether there are enough funds in order
      # to complete a transaction.
      def payment_allowed?(acct_no, amount)
        if DB[:Account].where(AcctNo: acct_no).first[:Balance].to_i <
           amount.to_i.fdiv(100)
          return false
        end
        true
      end

      # Get a user ID from a token, used as a utility method
      # in order to reduce the number of HTTP form values.
      def user_id_from_token(token)
        DB[:Token].select(:UserID).where(Token: token).first[:UserID]
      end

      # Get the user ID from the record for the specified account
      # then return whether it's equal to the user ID given.
      def account_belongs_to?(user, acct_no)
        acct_user = DB[:Account].where(AcctNo: acct_no).first[:UserID]
        acct_user == user
      end
    end
  end
end
