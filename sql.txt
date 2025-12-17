
CREATE TABLE Client (
    client_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE,
    registration_date DATE DEFAULT CURRENT_DATE,
    is_regular BOOLEAN DEFAULT FALSE,
    discount_percent DECIMAL(5,2) DEFAULT 0.00,
    CONSTRAINT valid_discount CHECK (discount_percent >= 0 AND discount_percent <= 50)
);

CREATE TABLE Car (
    car_id SERIAL PRIMARY KEY,
    client_id INT NOT NULL, -- УБРАЛИ UNIQUE!
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    year INT NOT NULL,
    color VARCHAR(30),
    license_plate VARCHAR(15) UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE, 
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (client_id) REFERENCES Client(client_id) ON DELETE CASCADE,
    CONSTRAINT valid_year CHECK (year >= 1990 AND year <= EXTRACT(YEAR FROM CURRENT_DATE) + 1)
);

CREATE TABLE Employee (
    employee_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    position VARCHAR(50) NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE,
    hire_date DATE DEFAULT CURRENT_DATE,
    salary DECIMAL(10,2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT positive_salary CHECK (salary > 0)
);

CREATE TABLE Service (
    service_id SERIAL PRIMARY KEY,
    service_name VARCHAR(100) NOT NULL UNIQUE,
    price DECIMAL(10,2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT positive_price CHECK (price > 0)
);

 CREATE TABLE "Order" (
    order_id SERIAL PRIMARY KEY,
    client_id INT NOT NULL,
    car_id INT NOT NULL, -- Конкретный автомобиль для этого заказа
    employee_id INT,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'pending',
    total_amount DECIMAL(12,2) DEFAULT 0,
    FOREIGN KEY (client_id) REFERENCES Client(client_id) ON DELETE CASCADE,
    FOREIGN KEY (car_id) REFERENCES Car(car_id) ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id) ON DELETE SET NULL,
    CONSTRAINT valid_status CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled'))
);


CREATE TABLE Material (
    material_id SERIAL PRIMARY KEY,
    material_name VARCHAR(100) NOT NULL UNIQUE,
    unit VARCHAR(20) NOT NULL,
    price_per_unit DECIMAL(10,2) NOT NULL,
    stock_quantity DECIMAL(10,2) DEFAULT 0,
    supplier VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT positive_price CHECK (price_per_unit > 0),
    CONSTRAINT positive_stock CHECK (stock_quantity >= 0)
);

-- Таблица Заказ-Услуга
CREATE TABLE Order_Service (
    order_service_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    service_id INT NOT NULL,
    employee_id INT,
    quantity INT DEFAULT 1,
    actual_price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES "Order"(order_id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES Service(service_id) ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id) ON DELETE SET NULL,
    CONSTRAINT positive_quantity CHECK (quantity > 0),
    CONSTRAINT positive_actual_price CHECK (actual_price > 0),
    UNIQUE(order_id, service_id)
);

-- Таблица использования материалов
CREATE TABLE Material_Usage (
    usage_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    material_id INT NOT NULL,
    employee_id INT,
    quantity_used DECIMAL(10,2) NOT NULL,
    usage_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cost DECIMAL(10,2) GENERATED ALWAYS AS (quantity_used * (
        SELECT price_per_unit FROM Material WHERE material_id = Material_Usage.material_id
    )) STORED,
    FOREIGN KEY (order_id) REFERENCES "Order"(order_id) ON DELETE CASCADE,
    FOREIGN KEY (material_id) REFERENCES Material(material_id) ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id) ON DELETE SET NULL,
    CONSTRAINT positive_quantity_used CHECK (quantity_used > 0)
);

-- Таблица Услуга-Материалы
CREATE TABLE Service_Material (
    service_material_id SERIAL PRIMARY KEY,
    service_id INT NOT NULL,
    material_id INT NOT NULL,
    required_quantity DECIMAL(10,3) NOT NULL,
    is_required BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (service_id) REFERENCES Service(service_id) ON DELETE CASCADE,
    FOREIGN KEY (material_id) REFERENCES Material(material_id) ON DELETE CASCADE,
    UNIQUE(service_id, material_id)
);

-- =============================================
-- ИНДЕКСЫ
-- =============================================
CREATE INDEX idx_client_phone ON Client(phone);
CREATE INDEX idx_car_client_id ON Car(client_id); -- Важный индекс для поиска машин клиента
CREATE INDEX idx_car_license_plate ON Car(license_plate);
CREATE INDEX idx_order_client_car ON "Order"(client_id, car_id);
CREATE INDEX idx_order_status ON "Order"(status);

    -- Проверяем, что указанный автомобиль принадлежит указанному клиенту
    IF NOT EXISTS (
        SELECT 1 FROM Car 
        WHERE car_id = NEW.car_id 
        AND client_id = NEW.client_id
        AND is_active = TRUE  -- Проверяем, что автомобиль активен
    ) THEN
        RAISE EXCEPTION 'Автомобиль с ID % не принадлежит клиенту с ID % или неактивен', 
                        NEW.car_id, NEW.client_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_order_client_car_1n
BEFORE INSERT OR UPDATE ON "Order"
FOR EACH ROW
EXECUTE FUNCTION validate_order_client_car_1n();

-- Функция для получения всех машин клиента
CREATE OR REPLACE FUNCTION get_client_cars(p_client_id INT)
RETURNS TABLE (
    car_id INT,
    brand VARCHAR,
    model VARCHAR,
    year INT,
    color VARCHAR,
    license_plate VARCHAR,
    is_active BOOLEAN,
    created_at TIMESTAMP,
    total_orders INT,
    last_order_date TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.car_id,
        c.brand,
        c.model,
        c.year,
        c.color,
        c.license_plate,
        c.is_active,
        c.created_at,
        COUNT(o.order_id)::INT AS total_orders,
        MAX(o.order_date) AS last_order_date
    FROM Car c
    LEFT JOIN "Order" o ON c.car_id = o.car_id
    WHERE c.client_id = p_client_id
    GROUP BY c.car_id, c.brand, c.model, c.year, c.color, 
             c.license_plate, c.is_active, c.created_at
    ORDER BY c.is_active DESC, c.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Функция для добавления новой машины клиенту
CREATE OR REPLACE FUNCTION add_car_to_client(
    p_client_id INT,
    p_brand VARCHAR,
    p_model VARCHAR,
    p_year INT,
    p_color VARCHAR,
    p_license_plate VARCHAR
) RETURNS INT AS $$
DECLARE
    v_car_id INT;
BEGIN
    -- Проверяем существование клиента
    IF NOT EXISTS (SELECT 1 FROM Client WHERE client_id = p_client_id) THEN
        RAISE EXCEPTION 'Клиент с ID % не найден', p_client_id;
    END IF;
    
    -- Проверяем уникальность госномера
    IF EXISTS (SELECT 1 FROM Car WHERE license_plate = p_license_plate) THEN
        RAISE EXCEPTION 'Автомобиль с номером % уже зарегистрирован', p_license_plate;
    END IF;
    
    -- Добавляем автомобиль
    INSERT INTO Car (client_id, brand, model, year, color, license_plate)
    VALUES (p_client_id, p_brand, p_model, p_year, p_color, p_license_plate)
    RETURNING car_id INTO v_car_id;
    
    RETURN v_car_id;
END;
$$ LANGUAGE plpgsql;

-- Функция для деактивации автомобиля (вместо удаления)
CREATE OR REPLACE FUNCTION deactivate_car(p_car_id INT)
RETURNS VOID AS $$
BEGIN
    -- Проверяем, нет ли активных заказов для этого автомобиля
    IF EXISTS (
        SELECT 1 FROM "Order" 
        WHERE car_id = p_car_id 
        AND status IN ('pending', 'in_progress')
    ) THEN
        RAISE EXCEPTION 'Нельзя деактивировать автомобиль с активными заказами';
    END IF;
    
    UPDATE Car 
    SET is_active = FALSE
    WHERE car_id = p_car_id;
    
    RAISE NOTICE 'Автомобиль с ID % деактивирован', p_car_id;
END;
$$ LANGUAGE plpgsql;

-- Обновленная функция для создания заказа (теперь нужно указывать car_id)
CREATE OR REPLACE FUNCTION create_order_with_car(
    p_client_id INT,
    p_car_id INT,
    p_employee_id INT
) RETURNS INT AS $$
DECLARE
    v_order_id INT;
BEGIN
    -- Автоматическая проверка триггером validate_order_client_car_1n
    
    -- Создание заказа
    INSERT INTO "Order" (client_id, car_id, employee_id)
    VALUES (p_client_id, p_car_id, p_employee_id)
    RETURNING order_id INTO v_order_id;
    
    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;

-- Функция для создания заказа с выбором автомобиля по умолчанию (первый активный)
CREATE OR REPLACE FUNCTION create_order_default_car(
    p_client_id INT,
    p_employee_id INT
) RETURNS INT AS $$
DECLARE
    v_car_id INT;
    v_order_id INT;
BEGIN
    -- Находим первый активный автомобиль клиента
    SELECT car_id INTO v_car_id
    FROM Car 
    WHERE client_id = p_client_id 
    AND is_active = TRUE
    ORDER BY created_at
    LIMIT 1;
    
    IF v_car_id IS NULL THEN
        RAISE EXCEPTION 'У клиента с ID % нет активных автомобилей', p_client_id;
    END IF;
    
    -- Создаем заказ
    SELECT create_order_with_car(p_client_id, v_car_id, p_employee_id) INTO v_order_id;
    
    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- ОБНОВЛЕННЫЕ ПРЕДСТАВЛЕНИЯ
-- =============================================

-- Представление: клиенты со всеми их автомобилями
CREATE OR REPLACE VIEW clients_with_cars AS
SELECT 
    c.client_id,
    c.full_name AS client_name,
    c.phone,
    c.email,
    c.registration_date,
    CASE c.is_regular 
        WHEN TRUE THEN 'Постоянный' 
        ELSE 'Новый' 
    END AS client_status,
    c.discount_percent || '%' AS discount,
    COUNT(DISTINCT car.car_id) AS total_cars,
    COUNT(DISTINCT CASE WHEN car.is_active THEN car.car_id END) AS active_cars,
    STRING_AGG(DISTINCT car.brand || ' ' || car.model, ', ') AS car_list,
    COUNT(o.order_id) AS total_orders,
    COALESCE(SUM(o.total_amount), 0) AS total_spent
FROM Client c
LEFT JOIN Car car ON c.client_id = car.client_id
LEFT JOIN "Order" o ON c.client_id = o.client_id
GROUP BY c.client_id, c.full_name, c.phone, c.email, 
         c.registration_date, c.is_regular, c.discount_percent
ORDER BY c.registration_date DESC;

-- Представление: детальная информация по автомобилям
CREATE OR REPLACE VIEW cars_detailed AS
SELECT 
    car.car_id,
    car.brand,
    car.model,
    car.year,
    car.color,
    car.license_plate,
    CASE car.is_active 
        WHEN TRUE THEN 'Активен' 
        ELSE 'Неактивен' 
    END AS car_status,
    car.created_at AS registration_date,
    c.client_id,
    c.full_name AS owner_name,
    c.phone AS owner_phone,
    COUNT(o.order_id) AS service_history,
    COALESCE(SUM(o.total_amount), 0) AS total_service_cost,
    MAX(o.order_date) AS last_service_date
FROM Car car
JOIN Client c ON car.client_id = c.client_id
LEFT JOIN "Order" o ON car.car_id = o.car_id AND o.status = 'completed'
GROUP BY car.car_id, car.brand, car.model, car.year, car.color, 
         car.license_plate, car.is_active, car.created_at,
         c.client_id, c.full_name, c.phone
ORDER BY car.is_active DESC, last_service_date DESC NULLS LAST;

-- Представление: статистика по автомобилям
CREATE OR REPLACE VIEW cars_statistics AS
SELECT 
    brand,
    COUNT(*) AS total_cars,
    COUNT(DISTINCT client_id) AS unique_owners,
    ROUND(AVG(year), 1) AS average_year,
    STRING_AGG(DISTINCT model, ', ') AS models,
    COUNT(CASE WHEN is_active THEN 1 END) AS active_cars,
    COUNT(CASE WHEN NOT is_active THEN 1 END) AS inactive_cars
FROM Car
GROUP BY brand
ORDER BY total_cars DESC;

-- =============================================
-- ТЕСТОВЫЕ ДАННЫЕ ДЛЯ ПРОВЕРКИ
-- =============================================

-- Вставляем тестовых клиентов
INSERT INTO Client (full_name, phone, email, is_regular, discount_percent) VALUES
('Иванов Иван Иванович', '+79161234567', 'ivanov@example.com', true, 10.00),
('Петрова Анна Сергеевна', '+79162345678', 'petrova@example.com', false, 0.00),
('Сидоров Алексей Викторович', '+79163456789', 'sidorov@example.com', true, 15.00);

-- Вставляем несколько машин для одного клиента (Иванов)
SELECT add_car_to_client(1, 'Toyota', 'Camry', 2020, 'черный', 'А123ВС777');
SELECT add_car_to_client(1, 'BMW', 'X5', 2022, 'белый', 'В456ОР777');
SELECT add_car_to_client(1, 'Mercedes', 'E-Class', 2019, 'серебристый', 'С789ТУ777');

-- Машины для других клиентов
SELECT add_car_to_client(2, 'Audi', 'Q7', 2021, 'синий', 'Е321КХ777');
SELECT add_car_to_client(3, 'Lexus', 'RX', 2023, 'красный', 'Х555НН777');
SELECT add_car_to_client(3, 'Volkswagen', 'Tiguan', 2020, 'серый', 'О222ММ777');

-- Добавляем сотрудников
INSERT INTO Employee (full_name, position, phone, email, salary) VALUES
('Волков Андрей Николаевич', 'мастер', '+79166789012', 'volkov@detailing.ru', 85000.00),
('Семенова Ольга Викторовна', 'администратор', '+79167890123', 'semenova@detailing.ru', 65000.00);

-- Добавляем услуги
INSERT INTO Service (service_name, price) VALUES
('Стандартная мойка', 1500.00),
('Комплексная мойка', 3000.00),
('Керамическое покрытие', 35000.00),
('Полировка кузова', 15000.00);

-- =============================================
-- ДЕМОНСТРАЦИОННЫЕ ЗАПРОСЫ
-- =============================================

-- 1. Показать всех клиентов и их автомобили
SELECT '=== Все клиенты и их автомобили ===' AS info;
SELECT * FROM clients_with_cars ORDER BY client_id;

-- 2. Показать все автомобили конкретного клиента (Иванова)
SELECT '=== Автомобили клиента Иванов И.И. ===' AS info;
SELECT * FROM get_client_cars(1);

-- 3. Создать заказ для Иванова на его Toyota
SELECT '=== Создание заказа для Toyota Иванова ===' AS info;
SELECT create_order_with_car(1, 1, 1) AS new_order_id;

-- 4. Создать заказ для Иванова на его BMW (автоматически выберется)
SELECT '=== Создание заказа для BMW Иванова (второй заказ) ===' AS info;
SELECT create_order_with_car(1, 2, 1) AS new_order_id;

-- 5. Попробовать создать заказ для несуществующей связи клиент-автомобиль
-- SELECT create_order_with_car(2, 1, 1); -- Должна быть ошибка

-- 6. Показать статистику по маркам автомобилей
SELECT '=== Статистика по маркам автомобилей ===' AS info;
SELECT * FROM cars_statistics;

-- 7. Показать детальную информацию по всем автомобилям
SELECT '=== Детальная информация по автомобилям ===' AS info;
SELECT * FROM cars_detailed ORDER BY owner_name, brand;

-- =============================================
-- ФИНАЛЬНОЕ СООБЩЕНИЕ
-- =============================================
DO $$
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'БАЗА ДАННЫХ УСПЕШНО СОЗДАНА И НАСТРОЕНА!';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Ключевые изменения:';
    RAISE NOTICE '• Связь Client-Car изменена с 1:1 на 1:N';
    RAISE NOTICE '• Один клиент теперь может иметь несколько машин';
    RAISE NOTICE '• При создании заказа необходимо указывать car_id';
    RAISE NOTICE '• Добавлен флаг is_active для автомобилей';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Для работы с несколькими машинами используйте:';
    RAISE NOTICE '• get_client_cars(client_id) - все машины клиента';
    RAISE NOTICE '• add_car_to_client() - добавить новую машину';
    RAISE NOTICE '• create_order_with_car() - создать заказ для машины';
    RAISE NOTICE '================================================';
END $$;
