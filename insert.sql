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
