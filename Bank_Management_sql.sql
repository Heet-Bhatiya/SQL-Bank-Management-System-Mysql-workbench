CREATE database BANK;
use BANK;
DROP TABLE IF EXISTS Transactions;
DROP TABLE IF EXISTS Accounts;
DROP TABLE IF EXISTS Loans;
DROP TABLE IF EXISTS Employees;
DROP TABLE IF EXISTS Customers;

-- Customers Table
CREATE TABLE Customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(100) NOT NULL,
    name VARCHAR(100),
    age INT,
    city VARCHAR(50),
    account_number BIGINT UNIQUE,
    balance DECIMAL(15,2) DEFAULT 0.00
);

-- Accounts Table
CREATE TABLE Accounts (
    account_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT,
    account_type ENUM('Savings', 'Current', 'Fixed Deposit'),
    balance DECIMAL(15,2),
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
);

-- Transactions Table  
-- (Note: The foreign key here references Customers.account_number for simplicity)
CREATE TABLE Transactions (
    transaction_id INT PRIMARY KEY AUTO_INCREMENT,
    account_number BIGINT,
    transaction_type ENUM('Deposit', 'Withdraw', 'Transfer'),
    amount DECIMAL(15,2),
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_number) REFERENCES Customers(account_number)
);

-- Loans Table
CREATE TABLE Loans (
    loan_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT,
    loan_type ENUM('Home Loan', 'Personal Loan', 'Education Loan'),
    amount DECIMAL(15,2),
    interest_rate DECIMAL(5,2),
    tenure INT, -- in months
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
);

-- Employees Table
CREATE TABLE Employees (
    employee_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100),
    designation VARCHAR(50),
    salary DECIMAL(10,2),
    branch VARCHAR(50)
);

-- Stored Procedure: SP_SignUp
DELIMITER //
CREATE PROCEDURE SP_SignUp (
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(100),
    IN p_name VARCHAR(100),
    IN p_age INT,
    IN p_city VARCHAR(50)
)
BEGIN
    DECLARE v_account_number BIGINT;
    DECLARE v_customer_id INT;
    
    -- Check if username exists:
    IF EXISTS (SELECT 1 FROM Customers WHERE username = p_username) THEN
         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Username already exists';
    END IF;
    
    -- Generate a random account number between 10000000 and 99999999
    SET v_account_number = FLOOR(10000000 + RAND() * 90000000);
    
    -- Insert into Customers:
    INSERT INTO Customers (username, password, name, age, city, account_number, balance)
    VALUES (p_username, p_password, p_name, p_age, p_city, v_account_number, 0.00);
    
    SET v_customer_id = LAST_INSERT_ID();
    
    -- Insert into Accounts (default account type: Savings)
    INSERT INTO Accounts (customer_id, account_type, balance)
    VALUES (v_customer_id, 'Savings', 0.00);
END //
DELIMITER ;

-- Stored Procedure: SP_SignIn
DELIMITER //
CREATE PROCEDURE SP_SignIn (
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(100),
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE v_pwd VARCHAR(100);
    SELECT password INTO v_pwd FROM Customers WHERE username = p_username;
    IF v_pwd = p_password THEN
         SET p_result = 'Login Successful';
    ELSE
         SET p_result = 'Invalid username or password';
    END IF;
END //
DELIMITER ;

-- Stored Procedure: SP_Deposit
DELIMITER //
CREATE PROCEDURE SP_Deposit (
    IN p_username VARCHAR(50),
    IN p_amount DECIMAL(15,2)
)
BEGIN
    DECLARE v_customer_id INT;
    DECLARE v_new_balance DECIMAL(15,2);
    DECLARE v_account_number BIGINT;
    
    SELECT customer_id, account_number, balance INTO v_customer_id, v_account_number, v_new_balance
    FROM Customers WHERE username = p_username;
    
    SET v_new_balance = v_new_balance + p_amount;
    
    UPDATE Customers SET balance = v_new_balance WHERE customer_id = v_customer_id;
    UPDATE Accounts SET balance = v_new_balance WHERE customer_id = v_customer_id;
    
    INSERT INTO Transactions (account_number, transaction_type, amount)
    VALUES (v_account_number, 'Deposit', p_amount);
END //
DELIMITER ;

-- Stored Procedure: SP_Withdraw
DELIMITER //
CREATE PROCEDURE SP_Withdraw (
    IN p_username VARCHAR(50),
    IN p_amount DECIMAL(15,2),
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE v_customer_id INT;
    DECLARE v_current_balance DECIMAL(15,2);
    DECLARE v_new_balance DECIMAL(15,2);
    DECLARE v_account_number BIGINT;
    
    SELECT customer_id, account_number, balance INTO v_customer_id, v_account_number, v_current_balance
    FROM Customers WHERE username = p_username;
    
    IF p_amount > v_current_balance THEN
         SET p_result = 'Insufficient Balance';
    ELSE
         SET v_new_balance = v_current_balance - p_amount;
         UPDATE Customers SET balance = v_new_balance WHERE customer_id = v_customer_id;
         UPDATE Accounts SET balance = v_new_balance WHERE customer_id = v_customer_id;
         INSERT INTO Transactions (account_number, transaction_type, amount)
         VALUES (v_account_number, 'Withdraw', p_amount);
         SET p_result = 'Withdrawal Successful';
    END IF;
END //
DELIMITER ;


-- Stored Procedure: SP_FundTransfer
DELIMITER //
CREATE PROCEDURE SP_FundTransfer (
    IN p_sender_username VARCHAR(50),
    IN p_receiver_account BIGINT,
    IN p_amount DECIMAL(15,2),
    OUT p_result VARCHAR(100)
)
proc: BEGIN
    DECLARE v_sender_id INT;
    DECLARE v_sender_balance DECIMAL(15,2);
    DECLARE v_sender_account BIGINT;
    DECLARE v_receiver_id INT;
    DECLARE v_receiver_balance DECIMAL(15,2);
    
    -- Get sender details:
    SELECT customer_id, account_number, balance 
      INTO v_sender_id, v_sender_account, v_sender_balance
      FROM Customers 
     WHERE username = p_sender_username;
    
    IF p_amount > v_sender_balance THEN
         SET p_result = 'Insufficient Balance';
         LEAVE proc;
    END IF;
    
    -- Get receiver details using account number:
    SELECT customer_id, balance 
      INTO v_receiver_id, v_receiver_balance
      FROM Customers 
     WHERE account_number = p_receiver_account;
    
    IF v_receiver_id IS NULL THEN
         SET p_result = 'Receiver Account Not Found';
         LEAVE proc;
    END IF;
    
    -- Deduct from sender:
    SET v_sender_balance = v_sender_balance - p_amount;
    UPDATE Customers SET balance = v_sender_balance WHERE customer_id = v_sender_id;
    UPDATE Accounts SET balance = v_sender_balance WHERE customer_id = v_sender_id;
    
    -- Add to receiver:
    SET v_receiver_balance = v_receiver_balance + p_amount;
    UPDATE Customers SET balance = v_receiver_balance WHERE customer_id = v_receiver_id;
    UPDATE Accounts SET balance = v_receiver_balance WHERE customer_id = v_receiver_id;
    
    -- Record transactions for both sender and receiver:
    INSERT INTO Transactions (account_number, transaction_type, amount)
    VALUES (v_sender_account, 'Transfer', p_amount);
    
    INSERT INTO Transactions (account_number, transaction_type, amount)
    VALUES (p_receiver_account, 'Deposit', p_amount);
    
    SET p_result = 'Fund Transfer Successful';
    
END proc //
DELIMITER ;

-- Stored Procedure: SP_BalanceEnquiry
DELIMITER //
CREATE PROCEDURE SP_BalanceEnquiry (
    IN p_username VARCHAR(50),
    OUT p_balance DECIMAL(15,2)
)
BEGIN
    SELECT balance INTO p_balance FROM Customers WHERE username = p_username;
END //
DELIMITER ;

-- Stored Procedure: SP_CreateLoan
DELIMITER //
CREATE PROCEDURE SP_CreateLoan (
    IN p_customer_id INT,
    IN p_loan_type ENUM('Home Loan', 'Personal Loan', 'Education Loan'),
    IN p_amount DECIMAL(15,2),
    IN p_interest_rate DECIMAL(5,2),
    IN p_tenure INT -- in months
)
BEGIN
    -- Check if customer exists
    IF NOT EXISTS (SELECT 1 FROM Customers WHERE customer_id = p_customer_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer does not exist';
    END IF;

    -- Insert new loan record
    INSERT INTO Loans (customer_id, loan_type, amount, interest_rate, tenure)
    VALUES (p_customer_id, p_loan_type, p_amount, p_interest_rate, p_tenure);
    
    SELECT 'Loan Created Successfully' AS Message;
END //
DELIMITER ;

-- Stored Procedure: SP_CreateEmployee
DELIMITER //
CREATE PROCEDURE SP_CreateEmployee (
    IN p_name VARCHAR(100),
    IN p_designation VARCHAR(50),
    IN p_salary DECIMAL(10,2),
    IN p_branch VARCHAR(50)
)
BEGIN
    -- Insert new employee record
    INSERT INTO Employees (name, designation, salary, branch)
    VALUES (p_name, p_designation, p_salary, p_branch);
    
    SELECT 'Employee Added Successfully' AS Message;
END //

DELIMITER ;

SELECT * FROM Customers;

SELECT * FROM Accounts;

SELECT * FROM Transactions;

SELECT * FROM Loans;

SELECT * FROM Employees;

SELECT COUNT(*) AS total_customers FROM Customers;

SELECT * FROM Transactions WHERE amount > 1000;

SELECT * FROM Loans WHERE customer_id = 1;

SELECT SUM(balance) AS total_savings_balance FROM Accounts WHERE account_type = 'Savings';

SELECT CONCAT(name, ' (', city, ')') AS Customer_Details, account_number, balance 
FROM Customers;

SELECT name, 'Customer' AS Type FROM Customers
UNION
SELECT name, 'Employee' AS Type FROM Employees;

SELECT name, balance FROM Customers WHERE balance = (SELECT MAX(balance) FROM Customers)
UNION
SELECT name, balance FROM Customers WHERE balance = (SELECT MIN(balance) FROM Customers);

SELECT Customers.name, Customers.city, Loans.loan_type, Loans.amount, Loans.interest_rate 
FROM Customers
INNER JOIN Loans ON Customers.customer_id = Loans.customer_id;

SELECT Customers.name, Customers.city, Loans.loan_type, IFNULL(Loans.amount, 0) AS Loan_Amount
FROM Customers
LEFT JOIN Loans ON Customers.customer_id = Loans.customer_id;


CALL SP_SignUp('vatsal', 'securePass123', 'John Doe', 30, 'bhavnagar');

SET @result = '';
CALL SP_SignIn('vatsal', 'securePass123', @result);
SELECT @result;

CALL SP_Deposit('vatsal', 500.00);

SET @result = '';
CALL SP_Withdraw('vatsal', 200.00, @result);
SELECT @result;

SET @result = '';
CALL SP_FundTransfer('vatsal', 2, 100.00, @result);
SELECT @result;

SET @balance = 0;
CALL SP_BalanceEnquiry('vatsal', @balance);
SELECT @balance;

CALL SP_CreateLoan(1, 'Home Loan', 500000.00, 7.5, 120);

CALL SP_CreateEmployee('heet', 'Branch Manager', 75000.00, 'surat');
