CREATE TABLE encryption_keys (
    key_id INT AUTO_INCREMENT PRIMARY KEY,
    key_name VARCHAR(50) NOT NULL,
    key_value VARBINARY(8000) NOT NULL,
    creation_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Tạo một khóa mã hóa ngẫu nhiên và lưu vào bảng
INSERT INTO encryption_keys (key_name, key_value) 
VALUES ('payment_encryption_key', UNHEX(SHA2(UUID(), 512)));


DELIMITER //

-- Hàm lấy khóa mã hóa hiện tại
CREATE FUNCTION get_encryption_key() RETURNS VARBINARY(8000)
DETERMINISTIC
BEGIN
    DECLARE current_key VARBINARY(8000);
    SELECT key_value INTO current_key FROM encryption_keys WHERE is_active = TRUE ORDER BY key_id DESC LIMIT 1;
    RETURN current_key;
END //

-- Hàm mã hóa chuỗi văn bản
CREATE FUNCTION encrypt_text(plaintext VARCHAR(255)) RETURNS VARBINARY(8000)
DETERMINISTIC
BEGIN
    DECLARE encryption_key VARBINARY(8000);
    SELECT get_encryption_key() INTO encryption_key;
    RETURN AES_ENCRYPT(plaintext, encryption_key);
END //

-- Hàm giải mã chuỗi văn bản
CREATE FUNCTION decrypt_text(ciphertext VARBINARY(8000)) RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
    DECLARE encryption_key VARBINARY(8000);
    SELECT get_encryption_key() INTO encryption_key;
    RETURN AES_DECRYPT(ciphertext, encryption_key);
END //

-- Hàm mã hóa số tiền
CREATE FUNCTION encrypt_decimal(amount DECIMAL(12,2)) RETURNS VARBINARY(8000)
DETERMINISTIC
BEGIN
    RETURN encrypt_text(CAST(amount AS CHAR));
END //

-- Hàm giải mã số tiền
CREATE FUNCTION decrypt_decimal(ciphertext VARBINARY(8000)) RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    RETURN CAST(decrypt_text(ciphertext) AS DECIMAL(12,2));
END //

DELIMITER ;
###########################

CREATE TABLE encrypted_payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    payment_method_encrypted VARBINARY(8000), -- Mã hóa phương thức thanh toán
    payment_date DATETIME, -- Không mã hóa ngày thanh toán để dễ tìm kiếm
    total_payment_encrypted VARBINARY(8000), -- Mã hóa số tiền
    account_id INT -- Không mã hóa ID tài khoản để dễ liên kết
);

-- Tạo view để làm việc với dữ liệu giải mã
CREATE VIEW payment_view AS
SELECT 
    id,
    decrypt_text(payment_method_encrypted) AS payment_method,
    payment_date,
    decrypt_decimal(total_payment_encrypted) AS total_payment,
    account_id
FROM encrypted_payments;

###############################

INSERT INTO encrypted_payments (payment_method_encrypted, payment_date, total_payment_encrypted, account_id)
SELECT 
    encrypt_text(payment_method),
    payment_date,
    encrypt_decimal(total_payment),
    account_id
FROM payments; -- Thay "payments" bằng tên bảng gốc của bạn

######################################

DELIMITER //

CREATE PROCEDURE add_payment(
     IN p_method VARCHAR(255), 
     IN p_date DATETIME, 
     IN p_amount DECIMAL(12,2), 
     IN p_account INT
)
BEGIN
     INSERT INTO encrypted_payments (
         payment_method_encrypted, 
         payment_date, 
         total_payment_encrypted, 
         account_id
     ) VALUES (
         encrypt_text(p_method), 
         p_date, 
         encrypt_decimal(p_amount), 
         p_account
     );  -- Thêm dấu chấm phẩy ở đây
END //  -- Thêm END và dấu //

DELIMITER ;
##########################

DELIMITER //

CREATE PROCEDURE update_payment(
     IN p_id INT, 
     IN p_method VARCHAR(255), 
     IN p_date DATETIME, 
     IN p_amount DECIMAL(12,2), 
     IN p_account INT
)
BEGIN
     UPDATE encrypted_payments SET 
         payment_method_encrypted = encrypt_text(p_method),
         payment_date = p_date,
         total_payment_encrypted = encrypt_decimal(p_amount),
         account_id = p_account
     WHERE id = p_id;  -- Thêm dấu chấm phẩy ở đây
END //  -- Thêm END và dấu //

DELIMITER ;

#########################
SELECT * FROM encrypted_payments WHERE account_id = 28;

CALL add_payment('VNPAY', '2025-05-23 15:30:00', 1500000.00, 28);

SELECT * FROM payment_view WHERE account_id = 28;

CALL update_payment(1, 'VNPAY', '2025-05-23 15:30:00', 1550000.00, 28);