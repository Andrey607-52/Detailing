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
    client_id INT NOT NULL, -- УБРАЛ UNIQUE!
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
