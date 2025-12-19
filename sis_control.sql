-- 0) Crear base de datos (charset recomendado)
CREATE DATABASE sis_control;

USE sis_control;


-- 1) Laboratorios
CREATE TABLE IF NOT EXISTS laboratorios (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  nombre      VARCHAR(100) NOT NULL,
  ubicacion   VARCHAR(150),
  CONSTRAINT uk_laboratorio_nombre UNIQUE (nombre)
);

-- 2) Equipos
CREATE TABLE IF NOT EXISTS equipos (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  etiqueta_activo   VARCHAR(64) NOT NULL,
  laboratorio_id    INT NOT NULL,
  tipo              VARCHAR(64),
  marca             VARCHAR(64),
  modelo            VARCHAR(64),
  estado            ENUM('operativo','programado','en_mantenimiento','de_baja') NOT NULL DEFAULT 'operativo',
  CONSTRAINT fk_equipos_lab FOREIGN KEY (laboratorio_id) REFERENCES laboratorios(id),
  CONSTRAINT uk_equipos_etiqueta UNIQUE (etiqueta_activo),
  KEY idx_equipos_lab_estado (laboratorio_id, estado),
  KEY idx_equipos_tipo_marca (tipo, marca)
);

-- 3) Usuarios (login simple por sesión)
CREATE TABLE IF NOT EXISTS usuarios (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  usuario    VARCHAR(50) NOT NULL,
  contrasena VARCHAR(200) NOT NULL,
  rol        ENUM('solo_vista','admin') NOT NULL DEFAULT 'solo_vista',
  CONSTRAINT uk_usuarios_usuario UNIQUE (usuario)
);

-- 4) Programaciones de mantenimiento (preventivas)
CREATE TABLE IF NOT EXISTS programaciones_mantenimiento (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  equipo_id         INT NOT NULL,
  periodicidad_dias INT NOT NULL,
  fecha_proxima     DATE NOT NULL,
  fecha_ultima      DATE NULL,
  CONSTRAINT fk_prog_equipo FOREIGN KEY (equipo_id) REFERENCES equipos(id),
  KEY idx_prog_equipo_proxima (equipo_id, fecha_proxima)
);

-- 5) Mantenimientos (preventivos/correctivos)
CREATE TABLE IF NOT EXISTS mantenimientos (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  equipo_id      INT NOT NULL,
  tipo           ENUM('preventivo','correctivo') NOT NULL,
  fecha_apertura DATETIME NOT NULL,
  fecha_cierre   DATETIME NULL,
  estado         ENUM('abierto','en_proceso','cerrado') NOT NULL DEFAULT 'abierto',
  descripcion    TEXT NULL,
  CONSTRAINT fk_mant_equipo FOREIGN KEY (equipo_id) REFERENCES equipos(id),
  KEY idx_mant_equipo_estado (equipo_id, estado),
  KEY idx_mant_fechas (fecha_apertura, fecha_cierre)
);

-- 6) Incidencias
CREATE TABLE IF NOT EXISTS incidencias (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  equipo_id        INT NOT NULL,
  reportada_por    INT NULL,          -- referencia usuarios.id
  fecha_reporte    DATETIME NOT NULL,
  severidad        ENUM('baja','media','alta') NOT NULL,
  descripcion      TEXT NULL,
  mantenimiento_id INT NULL,          -- opcional, referencia a mantenimientos.id
  CONSTRAINT fk_inc_equipo FOREIGN KEY (equipo_id) REFERENCES equipos(id),
  CONSTRAINT fk_inc_rep_por FOREIGN KEY (reportada_por) REFERENCES usuarios(id),
  CONSTRAINT fk_inc_mant FOREIGN KEY (mantenimiento_id) REFERENCES mantenimientos(id),
  KEY idx_inc_equipo_severidad (equipo_id, severidad),
  KEY idx_inc_fecha (fecha_reporte)
);

-- ==========================
-- VISTAS
-- ==========================

-- Vista: Programaciones próximas (corregida)
DROP VIEW IF EXISTS vista_programaciones_proximas;
CREATE VIEW vista_programaciones_proximas AS
SELECT
  p.id,
  p.equipo_id,
  e.etiqueta_activo,
  e.laboratorio_id,
  l.nombre AS laboratorio,
  p.periodicidad_dias,
  p.fecha_proxima,
  GREATEST(DATEDIFF(p.fecha_proxima, CURDATE()), 0) AS dias_restantes
FROM programaciones_mantenimiento p
JOIN equipos      e ON e.id = p.equipo_id
JOIN laboratorios l ON l.id = e.laboratorio_id
WHERE p.fecha_proxima >= CURDATE();

-- Vista: Mantenimientos con detalle
DROP VIEW IF EXISTS vista_mantenimientos_detalle;
CREATE VIEW vista_mantenimientos_detalle AS
SELECT
  m.id,
  m.tipo,
  m.estado,
  m.fecha_apertura,
  m.fecha_cierre,
  m.descripcion,
  e.id   AS equipo_id,
  e.etiqueta_activo,
  e.tipo  AS equipo_tipo,
  e.marca AS equipo_marca,
  e.modelo AS equipo_modelo,
  l.nombre    AS laboratorio,
  l.ubicacion AS laboratorio_ubicacion
FROM mantenimientos m
JOIN equipos      e ON e.id = m.equipo_id
JOIN laboratorios l ON l.id = e.laboratorio_id;

-- ==========================
-- SEED (20 registros por tabla)
-- ==========================

-- 1) Laboratorios (20)
INSERT INTO laboratorios (nombre, ubicacion) VALUES
('Lab Redes',           'Edificio A - Piso 2'),
('Lab Sistemas',        'Edificio B - Piso 1'),
('Lab Electrónica',     'Edificio D - Piso 1'),
('Lab Automatización',  'Edificio C - Piso 1'),
('Lab IoT',             'Edificio C - Piso 2'),
('Lab Seguridad',       'Edificio E - Piso 1'),
('Lab Energía',         'Edificio F - Piso 3'),
('Lab Datos',           'Edificio B - Piso 3'),
('Lab Cloud',           'Edificio G - Piso 1'),
('Lab AI',              'Edificio H - Piso 2'),
('Lab QA',              'Edificio A - Piso 1'),
('Lab DevOps',          'Edificio B - Piso 2'),
('Lab Multimedia',      'Edificio I - Piso 1'),
('Lab Física',          'Edificio J - Piso 1'),
('Lab Química',         'Edificio J - Piso 2'),
('Lab Biomed',          'Edificio K - Piso 1'),
('Lab Mecánica',        'Edificio L - Piso 2'),
('Lab Civil',           'Edificio M - Piso 3'),
('Lab Arquitectura',    'Edificio N - Piso 2'),
('Lab Redes Avanzadas', 'Edificio A - Piso 3');

-- 2) Usuarios (20)
INSERT INTO usuarios (usuario, contrasena, rol) VALUES
('admin',     'admin',     'admin'),
('visitante', 'visitante', 'solo_vista'),
('tecnico1',  'tecnico1',  'admin'),
('tecnico2',  'tecnico2',  'admin'),
('tecnico3',  'tecnico3',  'admin'),
('operador1', 'operador1', 'solo_vista'),
('operador2', 'operador2', 'solo_vista'),
('operador3', 'operador3', 'solo_vista'),
('auditor1',  'auditor1',  'solo_vista'),
('auditor2',  'auditor2',  'solo_vista'),
('dev1',      'dev1',      'admin'),
('dev2',      'dev2',      'admin'),
('qa1',       'qa1',       'solo_vista'),
('qa2',       'qa2',       'solo_vista'),
('soporte1',  'soporte1',  'admin'),
('soporte2',  'soporte2',  'admin'),
('seguridad1','seguridad1','admin'),
('seguridad2','seguridad2','admin'),
('redes1',    'redes1',    'admin'),
('redes2',    'redes2',    'admin');

-- 3) Equipos (20) - tipos/marcas variados
-- Laboratorio_id se refiere a IDs 1..20 creados arriba
INSERT INTO equipos (etiqueta_activo, laboratorio_id, tipo, marca, modelo, estado) VALUES
('PC-RED-001',   1,  'PC',          'Dell',      'OptiPlex 7000',     'operativo'),
('SW-RED-001',   1,  'Switch',      'Cisco',     'Catalyst 2960',     'operativo'),
('FW-RED-001',   1,  'Firewall',    'Fortinet',  'FortiGate 100E',    'en_mantenimiento'),
('PC-SIS-001',   2,  'PC',          'HP',        'ProDesk 600',       'operativo'),
('SRV-SIS-001',  2,  'Servidor',    'Lenovo',    'ThinkSystem SR650', 'programado'),
('PC-EL-001',    3,  'PC',          'Asus',      'ProArt Station',    'operativo'),
('OSC-EL-001',   3,  'Osciloscopio','Rigol',     'DS1104Z',           'operativo'),
('GEN-EL-001',   3,  'Generador',   'Keysight',  '33500B',            'de_baja'),
('PC-AUT-001',   4,  'PC',          'Acer',      'Veriton',           'operativo'),
('PLC-AUT-001',  4,  'PLC',         'Siemens',   'S7-1200',           'operativo'),
('AP-IOT-001',   5,  'AP',          'Ubiquiti',  'UAP-AC-Pro',        'operativo'),
('PC-SEG-001',   6,  'PC',          'Dell',      'Precision 3650',    'operativo'),
('CAM-SEG-001',  6,  'Cámara',      'Hikvision', 'DS-2CD2T47',        'operativo'),
('PC-ENE-001',   7,  'PC',          'Lenovo',    'M920',              'operativo'),
('INV-ENE-001',  7,  'Inversor',    'Schneider', 'Conext XW+',        'programado'),
('SRV-DAT-001',  8,  'Servidor',    'HPE',       'DL380 Gen10',       'operativo'),
('SW-CLO-001',   9,  'Switch',      'TP-Link',   'TL-SG3428',         'operativo'),
('SRV-AI-001',   10, 'Servidor',    'NVIDIA',    'DGX A100',          'en_mantenimiento'),
('PC-QA-001',    11, 'PC',          'Dell',      'OptiPlex 5090',     'operativo'),
('SRV-DEV-001',  12, 'Servidor',    'Supermicro','SYS-1029U',         'operativo');

-- 4) Programaciones de Mantenimiento (20)
-- Combinamos próximas dentro de 15/30/45/60 días, algunas pasadas y algunas muy futuras
INSERT INTO programaciones_mantenimiento (equipo_id, periodicidad_dias, fecha_proxima, fecha_ultima) VALUES
(1,  90,  DATE_ADD(CURDATE(), INTERVAL 15 DAY), NULL),
(2,  60,  DATE_ADD(CURDATE(), INTERVAL 30 DAY), CURDATE()),
(3,  90,  DATE_ADD(CURDATE(), INTERVAL 20 DAY), DATE_SUB(CURDATE(), INTERVAL 70 DAY)),
(4,  120, DATE_ADD(CURDATE(), INTERVAL 45 DAY), DATE_SUB(CURDATE(), INTERVAL 75 DAY)),
(5,  180, DATE_ADD(CURDATE(), INTERVAL 60 DAY), DATE_SUB(CURDATE(), INTERVAL 120 DAY)),
(6,  90,  DATE_ADD(CURDATE(), INTERVAL 10 DAY), NULL),
(7,  365, DATE_ADD(CURDATE(), INTERVAL 20 DAY), DATE_SUB(CURDATE(), INTERVAL 360 DAY)),
(8,  180, DATE_ADD(CURDATE(), INTERVAL 90 DAY), NULL),
(9,  60,  DATE_ADD(CURDATE(), INTERVAL 25 DAY), NULL),
(10, 30,  DATE_ADD(CURDATE(), INTERVAL 5 DAY),  DATE_SUB(CURDATE(), INTERVAL 25 DAY)),
(11, 60,  DATE_ADD(CURDATE(), INTERVAL 40 DAY), DATE_SUB(CURDATE(), INTERVAL 60 DAY)),
(12, 90,  DATE_ADD(CURDATE(), INTERVAL 12 DAY), NULL),
(13, 120, DATE_ADD(CURDATE(), INTERVAL 55 DAY), NULL),
(14, 180, DATE_ADD(CURDATE(), INTERVAL 100 DAY), NULL),
(15, 365, DATE_ADD(CURDATE(), INTERVAL 200 DAY), NULL),
(16, 60,  DATE_ADD(CURDATE(), INTERVAL 18 DAY), DATE_SUB(CURDATE(), INTERVAL 70 DAY)),
(17, 90,  DATE_ADD(CURDATE(), INTERVAL 50 DAY), NULL),
(18, 120, DATE_ADD(CURDATE(), INTERVAL 30 DAY), NULL),
(19, 60,  DATE_ADD(CURDATE(), INTERVAL 8 DAY),  NULL),
(20, 90,  DATE_ADD(CURDATE(), INTERVAL 75 DAY), DATE_SUB(CURDATE(), INTERVAL 90 DAY));

-- 5) Mantenimientos (20)
INSERT INTO mantenimientos (equipo_id, tipo, fecha_apertura, fecha_cierre, estado, descripcion) VALUES
(3,  'correctivo', CONCAT(CURDATE(), ' 09:00:00'), NULL, 'en_proceso', 'Revisión de fallos intermitentes en firewall'),
(2,  'preventivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 40 DAY), ' 10:00:00'), CONCAT(DATE_SUB(CURDATE(), INTERVAL 39 DAY), ' 12:30:00'), 'cerrado', 'Mantenimiento de switch de distribución'),
(5,  'preventivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 10 DAY), ' 08:30:00'), NULL, 'abierto', 'Plan de mantenimiento trimestral del servidor'),
(8,  'correctivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 2 DAY),  ' 14:00:00'), NULL, 'abierto', 'Generador no enciende'),
(1,  'preventivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 20 DAY), ' 09:30:00'), CONCAT(DATE_SUB(CURDATE(), INTERVAL 19 DAY), ' 11:00:00'), 'cerrado', 'Limpieza y revisión de PC'),
(4,  'preventivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 5 DAY),  ' 13:00:00'), NULL, 'en_proceso', 'Actualización de BIOS'),
(6,  'correctivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 3 DAY),  ' 10:45:00'), NULL, 'abierto', 'Fallo de fuente de poder'),
(7,  'preventivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 60 DAY), ' 08:00:00'), CONCAT(DATE_SUB(CURDATE(), INTERVAL 59 DAY), ' 16:00:00'), 'cerrado', 'Calibración osciloscopio'),
(9,  'preventivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 15 DAY), ' 11:15:00'), NULL, 'abierto', 'Mantenimiento rutinario de PC'),
(10, 'preventivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 7 DAY),  ' 09:00:00'), NULL, 'abierto', 'Inspección de PLC'),
(11, 'correctivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 1 DAY),  ' 15:30:00'), NULL, 'en_proceso', 'AP sin alimentación'),
(12, 'preventivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 25 DAY), ' 10:00:00'), CONCAT(DATE_SUB(CURDATE(), INTERVAL 24 DAY), ' 17:20:00'), 'cerrado', 'Revisión de estación de trabajo'),
(13, 'preventivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 22 DAY), ' 12:00:00'), NULL, 'abierto', 'Limpieza de cámara CCTV'),
(14, 'correctivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 8 DAY),  ' 09:40:00'), NULL, 'abierto', 'Alerta SMART en disco'),
(15, 'preventivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 30 DAY), ' 13:10:00'), NULL, 'en_proceso', 'Revisión de inversor'),
(16, 'correctivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 18 DAY), ' 08:50:00'), CONCAT(DATE_SUB(CURDATE(), INTERVAL 17 DAY), ' 11:00:00'), 'cerrado', 'Cambio de ventiladores'),
(17, 'preventivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 9 DAY),  ' 16:00:00'), NULL, 'abierto', 'Parcheo de seguridad'),
(18, 'correctivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 4 DAY),  ' 07:30:00'), NULL, 'abierto', 'Revisión de DGX A100'),
(19, 'preventivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 2 DAY),  ' 08:15:00'), NULL, 'en_proceso', 'Limpieza interna'),
(20, 'correctivo', CONCAT(DATE_SUB(CURDATE(), INTERVAL 1 DAY),  ' 10:20:00'), NULL, 'abierto', 'Fallo de arranque servidor');

-- 6) Incidencias (20)
-- Usuarios asumidos: admin(1), visitante(2), tecnico1(3), tecnico2(4), ..., redes2(20)
INSERT INTO incidencias (equipo_id, reportada_por, fecha_reporte, severidad, descripcion, mantenimiento_id) VALUES
(3,  3,  CONCAT(CURDATE(), ' 11:20:00'), 'alta',  'Pérdida de tráfico hacia WAN',          1),
(2,  4,  CONCAT(DATE_SUB(CURDATE(), INTERVAL 41 DAY), ' 09:15:00'), 'media', 'Interfaz Gi0/1 flap', 2),
(5,  3,  CONCAT(DATE_SUB(CURDATE(), INTERVAL 5 DAY),  ' 15:45:00'), 'baja',  'Alertas SMART del RAID', 3),
(8,  1,  CONCAT(DATE_SUB(CURDATE(), INTERVAL 2 DAY),  ' 14:30:00'), 'alta',  'Generador no enciende', 4),
(1,  6,  CONCAT(DATE_SUB(CURDATE(), INTERVAL 20 DAY), ' 10:05:00'), 'baja',  'Ruido excesivo del ventilador', 5),
(4,  7,  CONCAT(DATE_SUB(CURDATE(), INTERVAL 4 DAY),  ' 11:55:00'), 'media', 'Fallo de boot', 6),
(6,  8,  CONCAT(DATE_SUB(CURDATE(), INTERVAL 3 DAY),  ' 09:40:00'), 'alta',  'Fuente de poder quemada', 7),
(7,  9,  CONCAT(DATE_SUB(CURDATE(), INTERVAL 60 DAY), ' 13:20:00'), 'baja',  'Pantalla fosforito', 8),
(9,  10, CONCAT(DATE_SUB(CURDATE(), INTERVAL 15 DAY), ' 08:10:00'), 'media', 'Actualización pendiente', 9),
(10, 11, CONCAT(DATE_SUB(CURDATE(), INTERVAL 7 DAY),  ' 10:45:00'), 'alta',  'PLC sin programación', 10),
(11, 12, CONCAT(DATE_SUB(CURDATE(), INTERVAL 1 DAY),  ' 12:05:00'), 'media', 'AP reinicios frecuentes', 11),
(12, 13, CONCAT(DATE_SUB(CURDATE(), INTERVAL 25 DAY), ' 09:35:00'), 'baja',  'Ruido de ventilador', 12),
(13, 14, CONCAT(DATE_SUB(CURDATE(), INTERVAL 22 DAY), ' 16:20:00'), 'media', 'Imagen borrosa en CCTV', 13),
(14, 15, CONCAT(DATE_SUB(CURDATE(), INTERVAL 8 DAY),  ' 07:55:00'), 'alta',  'Sector fallando en HDD', 14),
(15, 16, CONCAT(DATE_SUB(CURDATE(), INTERVAL 30 DAY), ' 11:11:00'), 'baja',  'Ajuste de voltaje del inversor', 15),
(16, 17, CONCAT(DATE_SUB(CURDATE(), INTERVAL 18 DAY), ' 14:40:00'), 'media', 'Fan con ruido', 16),
(17, 18, CONCAT(DATE_SUB(CURDATE(), INTERVAL 9 DAY),  ' 10:22:00'), 'alta',  'Puertos expuestos', 17),
(18, 19, CONCAT(DATE_SUB(CURDATE(), INTERVAL 4 DAY),  ' 08:50:00'), 'media', 'GPU con temperatura elevada', 18),
(19, 20, CONCAT(DATE_SUB(CURDATE(), INTERVAL 2 DAY),  ' 09:35:00'), 'baja',  'Limpieza solicitada', 19),
(20, 5,  CONCAT(DATE_SUB(CURDATE(), INTERVAL 1 DAY),  ' 15:05:00'), 'alta',  'Kernel panic', 20);

-- ==========================
-- CHECKS RÁPIDOS
-- ==========================
SELECT 'laboratorios'   AS tabla, COUNT(*) AS total FROM laboratorios;
SELECT 'usuarios'       AS tabla, COUNT(*) AS total FROM usuarios;
SELECT 'equipos'        AS tabla, COUNT(*) AS total FROM equipos;
SELECT 'programaciones' AS tabla, COUNT(*) AS total FROM programaciones_mantenimiento;
SELECT 'mantenimientos' AS tabla, COUNT(*) AS total FROM mantenimientos;
SELECT 'incidencias'    AS tabla, COUNT(*) AS total FROM incidencias;

-- Verificación para "próximas" (hasta 60 días)
SELECT * 
FROM vista_programaciones_proximas
WHERE dias_restantes <= 60
ORDER BY fecha_pro
