require 'mail'

module Banking
  # Class for handling everything email-related
  class Email < Grape::API
    format :json

    Mail.defaults do
      delivery_method :smtp, address: 'mail.example.com',
                             domain: 'example.com',
                             user_name: 'user',
                             password: 'password',
                             authentication: :plain,
                             openssl_verify_mode: 'none'
    end

    post :register do
      mail = Mail.new
      mail.to = params[:email]
      mail.from = 'Banking Test <bankingtest@example.com>'
      mail.subject = 'More info about ' << params[:account]
      mail.body = File.open('info/' << params[:account]) { |file| file.read }
      mail.deliver!
      { success: true }
    end
  end
end
