# banking-with-grape

## Foreword

This project was built as part of a computer science team project module. As such, I would not really consider it entirely secure or production-friendly, and certainly would not use it in any kind of live installation without serious modification.

## Setup
1. Navigate to the main directory where the Gemfile is located, and run `bundler install` to prepare the prerequisites.

2. Load test data into your chosen database. The `banking.sql` file is included as example data, and is MySQL-based. For other databases, see [here](#notes-for-non-mysql-databases) for the changes that will need to be made.

3. Put in the basic parameters for the database connection in `common.rb` and the MTA (if applicable) in `email.rb`. To disable the email features, remove `mount Banking::Email` from `db.rb`.

4. Modify the shell file for your operating system (`start.bat` for Windows, `start.sh` for Linux or Mac) if necessary to change the port (default is 36280).

5. Launch the shell file to kick it into action.

6. The three device files contain the usernames and passwords for the example data (they are hashed and salted in the database, so it's not easily possible to recover them), use the username and password along with the file name as the device id to log in.

**Note:** This is confirmed working on Ubuntu, not tested on Windows.

## Routes

All routes return JSON objects.
All routes begin from the host route (eg http://localhost/login).

### return.rb

#### login
* Takes parameters `username`, `password`, `dev_id`.
* returns `{ auth: false }` if the username does not exist, or the password isn't correct for the username, or if the device is not a valid device for the user.
* returns `{ auth: true }` along with an initialised name and a token used to perform further actions in the system. The token expires 600 seconds after it is last used.

#### transactions
* Takes parameters `token`, `acct_no`, `page`, `count` (optional).
* returns `{ auth: false }` if the token is invalid.
* returns `{ auth: true }` along with a JSON array of transactions based on the page number submitted, and returns count if not specified in the parameters, intended to allow the client to restrict the sent page count to within allowable bounds. 
* If page goes past the end of the transactions, it will return an empty JSON set.

#### payees
* Takes parameter `token`
* returns `{ auth: false }` if the token is invalid.
* returns `{ auth: true }` along with a JSON array of payees linked to the user account.

#### accounts
* Takes parameter `token`
* returns `{ auth: false }` if the token is invalid.
* returns `{ auth: true }` along with a JSON array of accounts linked to the user.

### process.rb

#### transfer
* Takes parameters `token`, `acct_no`, `acct_to`, `amount`.
* returns `{ auth: false }` if the token is invalid.
* returns `{ auth: true, success: false, reason: "balance" } ` if there is not enough money in the account to cover the transfer.
* returns `{ auth: true, success: false, reason: "account" } ` if the account given does not belong to the same user
* returns `{ auth: true, success: false, reason: "user" }` if the account the money is leaving does not belong to the same user as the token.
* returns `{ auth: true, success: true}` if the transfer is successful.
* Transfers can only be done between accounts belonging to the same user.

#### payment
* Takes parameters `token`, `acct_no`, `acct_to`, `amount`, `reference`.
* returns `{ auth: false }` if the token is invalid.
* returns `{ auth: true, success: false, reason: "balance" } ` if there is not enough money in the account to cover the payment.
* returns `{ auth: true, success: false, reason: "payee" } ` if the payee is not in the list of payees for the user.
* returns `{ auth: true, success: false, reason: "user" }` if the account the money is leaving does not belong to the same user as the token.
* returns `{ auth: true, success: true}` if the payment is successful.
* Payments are done between accounts belonging to different users.

### email.rb

#### register
* Takes parameters `email`, `account`.
* returns `{ success: true }` for the sake of returning a JSON object
* will return a 500 internal server error if sending email fails.
* The value of `account` refers to the name of a file that exists within the `info` directory inside the `src` directory, which will need to be created and populated.

### See also
* [banking-with-retrofit](https://github.com/JudgeZarbi/banking-with-retrofit) - An example client to work with this backend, written for Android using retrofit.