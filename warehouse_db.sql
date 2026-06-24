DROP DATABASE IF EXISTS warehouse_db;
CREATE DATABASE warehouse_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE warehouse_db;

-- ----------------------- СТРУКТУРА -----------------------
CREATE TABLE category (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE supplier (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(150) NOT NULL,
    phone       VARCHAR(20),
    email       VARCHAR(100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE product (
    product_id  INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(150) NOT NULL,
    category_id INT NOT NULL,
    supplier_id INT NOT NULL,
    unit        VARCHAR(20) NOT NULL DEFAULT 'шт',
    price       DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    CONSTRAINT fk_product_category FOREIGN KEY (category_id) REFERENCES category(category_id),
    CONSTRAINT fk_product_supplier FOREIGN KEY (supplier_id) REFERENCES supplier(supplier_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE zone (
    zone_id     INT AUTO_INCREMENT PRIMARY KEY,
    code        VARCHAR(20) NOT NULL UNIQUE,
    description VARCHAR(150)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE app_user (
    user_id   INT AUTO_INCREMENT PRIMARY KEY,
    login     VARCHAR(50) NOT NULL UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    role      ENUM('admin','storekeeper') NOT NULL DEFAULT 'storekeeper'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE stock (
    stock_id   INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    zone_id    INT NOT NULL,
    quantity   INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    CONSTRAINT fk_stock_product FOREIGN KEY (product_id) REFERENCES product(product_id),
    CONSTRAINT fk_stock_zone    FOREIGN KEY (zone_id)    REFERENCES zone(zone_id),
    CONSTRAINT uq_stock UNIQUE (product_id, zone_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE operation (
    operation_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id   INT NOT NULL,
    zone_id      INT NOT NULL,
    user_id      INT NOT NULL,
    op_type      ENUM('IN','OUT','MOVE') NOT NULL,
    quantity     INT NOT NULL CHECK (quantity > 0),
    op_date      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_op_product FOREIGN KEY (product_id) REFERENCES product(product_id),
    CONSTRAINT fk_op_zone    FOREIGN KEY (zone_id)    REFERENCES zone(zone_id),
    CONSTRAINT fk_op_user    FOREIGN KEY (user_id)    REFERENCES app_user(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------- ДАННЫЕ -----------------------
INSERT INTO category (name) VALUES
('Бытовая техника'),('Продукты питания'),('Канцтовары'),('Электроника'),('Хозтовары');

INSERT INTO supplier (name, phone, email) VALUES
('ООО Поставка-Сервис','+7-900-111-22-33','info@postavka.ru'),
('АО ТехноОпт','+7-901-222-33-44','sales@technoopt.ru'),
('ИП Сидоров В.А.','+7-902-333-44-55','sidorov@mail.ru'),
('ООО ПродуктТорг','+7-903-444-55-66','opt@prodtorg.ru'),
('ООО ОфисМир','+7-904-555-66-77','zakaz@ofismir.ru');

INSERT INTO product (name, category_id, supplier_id, unit, price) VALUES
('Чайник электрический',1,2,'шт',1890.00),
('Кофе молотый 250г',2,4,'шт',320.50),
('Бумага A4 500л',3,5,'пач',450.00),
('Наушники беспроводные',4,2,'шт',2750.00),
('Перчатки хозяйственные',5,3,'пар',89.90);

INSERT INTO zone (code, description) VALUES
('A-01-01','Ряд A, стеллаж 01, полка 01'),
('A-01-02','Ряд A, стеллаж 01, полка 02'),
('B-02-01','Ряд B, стеллаж 02, полка 01'),
('B-02-02','Ряд B, стеллаж 02, полка 02'),
('C-03-01','Ряд C, зона крупногабарита');

INSERT INTO app_user (login, full_name, role) VALUES
('admin','Азизов Сергей Маратович','admin'),
('ivanov','Иванов Иван Иванович','storekeeper'),
('petrov','Петров Пётр Петрович','storekeeper'),
('sidorova','Сидорова Анна Олеговна','storekeeper'),
('kozlov','Козлов Дмитрий Сергеевич','storekeeper');

INSERT INTO stock (product_id, zone_id, quantity) VALUES
(1,1,25),(2,2,140),(3,3,60),(4,1,18),(5,4,300);

INSERT INTO operation (product_id, zone_id, user_id, op_type, quantity) VALUES
(1,1,2,'IN',25),(2,2,2,'IN',150),(3,3,3,'IN',60),
(4,1,3,'IN',20),(5,4,4,'IN',300),(2,2,2,'OUT',10);

-- ----------------------- РОЛИ И ПРАВА -----------------------
CREATE ROLE IF NOT EXISTS 'admin_role','storekeeper_role';
GRANT ALL PRIVILEGES ON warehouse_db.* TO 'admin_role';
GRANT SELECT, INSERT, UPDATE ON warehouse_db.product   TO 'storekeeper_role';
GRANT SELECT, INSERT, UPDATE ON warehouse_db.stock     TO 'storekeeper_role';
GRANT SELECT, INSERT          ON warehouse_db.operation TO 'storekeeper_role';
GRANT SELECT ON warehouse_db.category TO 'storekeeper_role';
GRANT SELECT ON warehouse_db.supplier TO 'storekeeper_role';
GRANT SELECT ON warehouse_db.zone     TO 'storekeeper_role';

CREATE USER IF NOT EXISTS 'wh_admin'@'localhost'       IDENTIFIED BY 'Admin#2025';
CREATE USER IF NOT EXISTS 'wh_storekeeper'@'localhost' IDENTIFIED BY 'Store#2025';
GRANT 'admin_role'       TO 'wh_admin'@'localhost';
GRANT 'storekeeper_role' TO 'wh_storekeeper'@'localhost';
SET DEFAULT ROLE ALL TO 'wh_admin'@'localhost','wh_storekeeper'@'localhost';
FLUSH PRIVILEGES;

-- ----------------------- ТРИГГЕР -----------------------
DELIMITER //
CREATE TRIGGER trg_operation_after_insert
AFTER INSERT ON operation
FOR EACH ROW
BEGIN
    DECLARE v_current INT DEFAULT 0;
    IF NEW.op_type = 'IN' THEN
        INSERT INTO stock (product_id, zone_id, quantity)
        VALUES (NEW.product_id, NEW.zone_id, NEW.quantity)
        ON DUPLICATE KEY UPDATE quantity = quantity + NEW.quantity;
    ELSEIF NEW.op_type = 'OUT' THEN
        UPDATE stock SET quantity = quantity - NEW.quantity
        WHERE product_id = NEW.product_id AND zone_id = NEW.zone_id;
    END IF;
END//
DELIMITER ;

-- ----------------------- ФУНКЦИЯ -----------------------
DELIMITER //
CREATE FUNCTION fn_stock_value(p_product_id INT)
RETURNS DECIMAL(14,2) DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_total_qty INT DEFAULT 0;
    DECLARE v_price     DECIMAL(10,2) DEFAULT 0;
    DECLARE v_value     DECIMAL(14,2) DEFAULT 0;
    SELECT IFNULL(SUM(quantity),0) INTO v_total_qty FROM stock WHERE product_id = p_product_id;
    SELECT price INTO v_price FROM product WHERE product_id = p_product_id;
    SET v_value = v_total_qty * v_price;
    RETURN v_value;
END//
DELIMITER ;

-- ----------------------- ПРЕДСТАВЛЕНИЕ -----------------------
CREATE OR REPLACE VIEW v_stock_report AS
SELECT p.product_id, p.name AS product_name, c.name AS category_name,
       z.code AS zone_code, s.quantity, p.price, (s.quantity*p.price) AS total_value
FROM stock s
JOIN product  p ON p.product_id  = s.product_id
JOIN category c ON c.category_id = p.category_id
JOIN zone     z ON z.zone_id     = s.zone_id
ORDER BY p.name;

-- ----------------------- ПРОЦЕДУРА ПРИЁМКИ -----------------------
DELIMITER //
CREATE PROCEDURE sp_receive_product(
    IN p_product_id INT, IN p_zone_id INT, IN p_user_id INT, IN p_qty INT,
    OUT p_result VARCHAR(255))
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE v_zone   INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; SET p_result='Ошибка: операция приёмки отменена.'; END;
    IF p_qty <= 0 THEN
        SET p_result='Ошибка: количество должно быть больше нуля.';
    ELSE
        START TRANSACTION;
        SELECT COUNT(*) INTO v_exists FROM product WHERE product_id=p_product_id;
        SELECT COUNT(*) INTO v_zone   FROM zone    WHERE zone_id=p_zone_id;
        IF v_exists=0 OR v_zone=0 THEN
            SET p_result='Ошибка: товар или зона не найдены.'; ROLLBACK;
        ELSE
            INSERT INTO operation (product_id, zone_id, user_id, op_type, quantity)
            VALUES (p_product_id, p_zone_id, p_user_id, 'IN', p_qty);
            COMMIT;
            SET p_result=CONCAT('Принято ',p_qty,' ед. товара #',p_product_id);
        END IF;
    END IF;
END//
DELIMITER ;

-- ----------------------- ПРОЦЕДУРА ПЕРЕМЕЩЕНИЯ (ТРАНЗАКЦИЯ) -----------------------
DELIMITER //
CREATE PROCEDURE sp_move_product(
    IN p_product_id INT, IN p_from_zone INT, IN p_to_zone INT,
    IN p_user_id INT, IN p_qty INT, OUT p_result VARCHAR(255))
BEGIN
    DECLARE v_available INT DEFAULT 0;
    DECLARE v_msg VARCHAR(255) DEFAULT '';
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; SET p_result='Ошибка СУБД: перемещение отменено (откат транзакции).'; END;
    START TRANSACTION;
    SELECT IFNULL(quantity,0) INTO v_available
    FROM stock WHERE product_id=p_product_id AND zone_id=p_from_zone;
    IF v_available < p_qty THEN
        SET p_result='Недостаточно товара в исходной зоне.'; ROLLBACK;
    ELSE
        UPDATE stock SET quantity=quantity-p_qty
        WHERE product_id=p_product_id AND zone_id=p_from_zone;
        INSERT INTO stock (product_id, zone_id, quantity)
        VALUES (p_product_id, p_to_zone, p_qty)
        ON DUPLICATE KEY UPDATE quantity=quantity+p_qty;
        INSERT INTO operation (product_id, zone_id, user_id, op_type, quantity)
        VALUES (p_product_id, p_to_zone, p_user_id, 'MOVE', p_qty);
        COMMIT;
        SET p_result=CONCAT('Перемещено ',p_qty,' ед. из зоны ',p_from_zone,' в зону ',p_to_zone);
    END IF;
END//
DELIMITER ;
