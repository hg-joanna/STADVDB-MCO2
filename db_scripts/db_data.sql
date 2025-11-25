-- DATA FOR OLTP

-- Flights
INSERT INTO flights (flight_number, origin, destination, departure_time, arrival_time)
VALUES
('FL001','Manila','Cebu','2025-12-01 08:00:00+08','2025-12-01 09:30:00+08'),
('FL002','Cebu','Davao','2025-12-01 10:00:00+08','2025-12-01 11:15:00+08'),
('FL003','Davao','Iloilo','2025-12-01 12:00:00+08','2025-12-01 13:30:00+08'),
('FL004','Iloilo','Manila','2025-12-01 14:00:00+08','2025-12-01 15:30:00+08'),
('FL005','Manila','Davao','2025-12-02 08:00:00+08','2025-12-02 09:45:00+08'),
('FL006','Cebu','Manila','2025-12-02 10:00:00+08','2025-12-02 11:30:00+08'),
('FL007','Davao','Cebu','2025-12-02 12:00:00+08','2025-12-02 13:15:00+08'),
('FL008','Iloilo','Cebu','2025-12-02 14:00:00+08','2025-12-02 15:15:00+08'),
('FL009','Manila','Iloilo','2025-12-03 08:00:00+08','2025-12-03 09:30:00+08'),
('FL010','Cebu','Davao','2025-12-03 10:00:00+08','2025-12-03 11:15:00+08')
ON CONFLICT DO NOTHING;

-- Seats
-- Seat pattern: 1A–5B, 8 ECONOMY + 2 BUSINESS per flight
INSERT INTO seats (flight_id, seat_number, seat_class, is_available)
VALUES
-- Flight 1
(1,'1A','ECONOMY',TRUE),(1,'1B','ECONOMY',TRUE),(1,'2A','ECONOMY',TRUE),(1,'2B','ECONOMY',TRUE),
(1,'3A','ECONOMY',TRUE),(1,'3B','ECONOMY',TRUE),(1,'4A','ECONOMY',TRUE),(1,'4B','ECONOMY',TRUE),
(1,'5A','BUSINESS',TRUE),(1,'5B','BUSINESS',TRUE),

-- Flight 2
(2,'1A','ECONOMY',TRUE),(2,'1B','ECONOMY',TRUE),(2,'2A','ECONOMY',TRUE),(2,'2B','ECONOMY',TRUE),
(2,'3A','ECONOMY',TRUE),(2,'3B','ECONOMY',TRUE),(2,'4A','ECONOMY',TRUE),(2,'4B','ECONOMY',TRUE),
(2,'5A','BUSINESS',TRUE),(2,'5B','BUSINESS',TRUE),

-- Flight 3
(3,'1A','ECONOMY',TRUE),(3,'1B','ECONOMY',TRUE),(3,'2A','ECONOMY',TRUE),(3,'2B','ECONOMY',TRUE),
(3,'3A','ECONOMY',TRUE),(3,'3B','ECONOMY',TRUE),(3,'4A','ECONOMY',TRUE),(3,'4B','ECONOMY',TRUE),
(3,'5A','BUSINESS',TRUE),(3,'5B','BUSINESS',TRUE),

-- Flight 4
(4,'1A','ECONOMY',TRUE),(4,'1B','ECONOMY',TRUE),(4,'2A','ECONOMY',TRUE),(4,'2B','ECONOMY',TRUE),
(4,'3A','ECONOMY',TRUE),(4,'3B','ECONOMY',TRUE),(4,'4A','ECONOMY',TRUE),(4,'4B','ECONOMY',TRUE),
(4,'5A','BUSINESS',TRUE),(4,'5B','BUSINESS',TRUE),

-- Flight 5
(5,'1A','ECONOMY',TRUE),(5,'1B','ECONOMY',TRUE),(5,'2A','ECONOMY',TRUE),(5,'2B','ECONOMY',TRUE),
(5,'3A','ECONOMY',TRUE),(5,'3B','ECONOMY',TRUE),(5,'4A','ECONOMY',TRUE),(5,'4B','ECONOMY',TRUE),
(5,'5A','BUSINESS',TRUE),(5,'5B','BUSINESS',TRUE),

-- Flight 6
(6,'1A','ECONOMY',TRUE),(6,'1B','ECONOMY',TRUE),(6,'2A','ECONOMY',TRUE),(6,'2B','ECONOMY',TRUE),
(6,'3A','ECONOMY',TRUE),(6,'3B','ECONOMY',TRUE),(6,'4A','ECONOMY',TRUE),(6,'4B','ECONOMY',TRUE),
(6,'5A','BUSINESS',TRUE),(6,'5B','BUSINESS',TRUE),

-- Flight 7
(7,'1A','ECONOMY',TRUE),(7,'1B','ECONOMY',TRUE),(7,'2A','ECONOMY',TRUE),(7,'2B','ECONOMY',TRUE),
(7,'3A','ECONOMY',TRUE),(7,'3B','ECONOMY',TRUE),(7,'4A','ECONOMY',TRUE),(7,'4B','ECONOMY',TRUE),
(7,'5A','BUSINESS',TRUE),(7,'5B','BUSINESS',TRUE),

-- Flight 8
(8,'1A','ECONOMY',TRUE),(8,'1B','ECONOMY',TRUE),(8,'2A','ECONOMY',TRUE),(8,'2B','ECONOMY',TRUE),
(8,'3A','ECONOMY',TRUE),(8,'3B','ECONOMY',TRUE),(8,'4A','ECONOMY',TRUE),(8,'4B','ECONOMY',TRUE),
(8,'5A','BUSINESS',TRUE),(8,'5B','BUSINESS',TRUE),

-- Flight 9
(9,'1A','ECONOMY',TRUE),(9,'1B','ECONOMY',TRUE),(9,'2A','ECONOMY',TRUE),(9,'2B','ECONOMY',TRUE),
(9,'3A','ECONOMY',TRUE),(9,'3B','ECONOMY',TRUE),(9,'4A','ECONOMY',TRUE),(9,'4B','ECONOMY',TRUE),
(9,'5A','BUSINESS',TRUE),(9,'5B','BUSINESS',TRUE),

-- Flight 10
(10,'1A','ECONOMY',TRUE),(10,'1B','ECONOMY',TRUE),(10,'2A','ECONOMY',TRUE),(10,'2B','ECONOMY',TRUE),
(10,'3A','ECONOMY',TRUE),(10,'3B','ECONOMY',TRUE),(10,'4A','ECONOMY',TRUE),(10,'4B','ECONOMY',TRUE),
(10,'5A','BUSINESS',TRUE),(10,'5B','BUSINESS',TRUE)
ON CONFLICT DO NOTHING;

-- Customers (100)
INSERT INTO customers (full_name, email, phone)
VALUES
('Customer1','customer1@example.com','09170000001'),
('Customer2','customer2@example.com','09170000002'),
('Customer3','customer3@example.com','09170000003'),
('Customer4','customer4@example.com','09170000004'),
('Customer5','customer5@example.com','09170000005'),
('Customer6','customer6@example.com','09170000006'),
('Customer7','customer7@example.com','09170000007'),
('Customer8','customer8@example.com','09170000008'),
('Customer9','customer9@example.com','09170000009'),
('Customer10','customer10@example.com','09170000010'),
('Customer11','customer11@example.com','09170000011'),
('Customer12','customer12@example.com','09170000012'),
('Customer13','customer13@example.com','09170000013'),
('Customer14','customer14@example.com','09170000014'),
('Customer15','customer15@example.com','09170000015'),
('Customer16','customer16@example.com','09170000016'),
('Customer17','customer17@example.com','09170000017'),
('Customer18','customer18@example.com','09170000018'),
('Customer19','customer19@example.com','09170000019'),
('Customer20','customer20@example.com','09170000020'),
('Customer21','customer21@example.com','09170000021'),
('Customer22','customer22@example.com','09170000022'),
('Customer23','customer23@example.com','09170000023'),
('Customer24','customer24@example.com','09170000024'),
('Customer25','customer25@example.com','09170000025'),
('Customer26','customer26@example.com','09170000026'),
('Customer27','customer27@example.com','09170000027'),
('Customer28','customer28@example.com','09170000028'),
('Customer29','customer29@example.com','09170000029'),
('Customer30','customer30@example.com','09170000030'),
('Customer31','customer31@example.com','09170000031'),
('Customer32','customer32@example.com','09170000032'),
('Customer33','customer33@example.com','09170000033'),
('Customer34','customer34@example.com','09170000034'),
('Customer35','customer35@example.com','09170000035'),
('Customer36','customer36@example.com','09170000036'),
('Customer37','customer37@example.com','09170000037'),
('Customer38','customer38@example.com','09170000038'),
('Customer39','customer39@example.com','09170000039'),
('Customer40','customer40@example.com','09170000040'),
('Customer41','customer41@example.com','09170000041'),
('Customer42','customer42@example.com','09170000042'),
('Customer43','customer43@example.com','09170000043'),
('Customer44','customer44@example.com','09170000044'),
('Customer45','customer45@example.com','09170000045'),
('Customer46','customer46@example.com','09170000046'),
('Customer47','customer47@example.com','09170000047'),
('Customer48','customer48@example.com','09170000048'),
('Customer49','customer49@example.com','09170000049'),
('Customer50','customer50@example.com','09170000050'),
('Customer51','customer51@example.com','09170000051'),
('Customer52','customer52@example.com','09170000052'),
('Customer53','customer53@example.com','09170000053'),
('Customer54','customer54@example.com','09170000054'),
('Customer55','customer55@example.com','09170000055'),
('Customer56','customer56@example.com','09170000056'),
('Customer57','customer57@example.com','09170000057'),
('Customer58','customer58@example.com','09170000058'),
('Customer59','customer59@example.com','09170000059'),
('Customer60','customer60@example.com','09170000060'),
('Customer61','customer61@example.com','09170000061'),
('Customer62','customer62@example.com','09170000062'),
('Customer63','customer63@example.com','09170000063'),
('Customer64','customer64@example.com','09170000064'),
('Customer65','customer65@example.com','09170000065'),
('Customer66','customer66@example.com','09170000066'),
('Customer67','customer67@example.com','09170000067'),
('Customer68','customer68@example.com','09170000068'),
('Customer69','customer69@example.com','09170000069'),
('Customer70','customer70@example.com','09170000070'),
('Customer71','customer71@example.com','09170000071'),
('Customer72','customer72@example.com','09170000072'),
('Customer73','customer73@example.com','09170000073'),
('Customer74','customer74@example.com','09170000074'),
('Customer75','customer75@example.com','09170000075'),
('Customer76','customer76@example.com','09170000076'),
('Customer77','customer77@example.com','09170000077'),
('Customer78','customer78@example.com','09170000078'),
('Customer79','customer79@example.com','09170000079'),
('Customer80','customer80@example.com','09170000080'),
('Customer81','customer81@example.com','09170000081'),
('Customer82','customer82@example.com','09170000082'),
('Customer83','customer83@example.com','09170000083'),
('Customer84','customer84@example.com','09170000084'),
('Customer85','customer85@example.com','09170000085'),
('Customer86','customer86@example.com','09170000086'),
('Customer87','customer87@example.com','09170000087'),
('Customer88','customer88@example.com','09170000088'),
('Customer89','customer89@example.com','09170000089'),
('Customer90','customer90@example.com','09170000090'),
('Customer91','customer91@example.com','09170000091'),
('Customer92','customer92@example.com','09170000092'),
('Customer93','customer93@example.com','09170000093'),
('Customer94','customer94@example.com','09170000094'),
('Customer95','customer95@example.com','09170000095'),
('Customer96','customer96@example.com','09170000096'),
('Customer97','customer97@example.com','09170000097'),
('Customer98','customer98@example.com','09170000098'),
('Customer99','customer99@example.com','09170000099'),
('Customer100','customer100@example.com','09170000100')
ON CONFLICT DO NOTHING;
