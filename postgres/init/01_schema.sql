-- ============================================================================
--  Esquema para DATOS REALES del Cubo 9 SIGCOM (Dashboard_SIGCOM.xlsx)
--  Hospital San Jose de Coronel  -  36 centros de costo, ene-2024 a jul-2026
--
--  Misma logica de costos del Cubo 9:
--     Recurso Humano + Gastos Generales + Insumos      = Costo Directo
--     Costo Directo  + Costo Indirecto                 = Costo Total
--
--  Reemplaza por completo el esquema con datos de ejemplo.
-- ============================================================================

DROP VIEW  IF EXISTS v_costo_por_egreso, v_costo_por_dco, v_produccion_efectiva, v_alos,
                     v_ejecucion_presupuestaria, v_eficiencia_facturacion,
                     v_gasto_hospital, v_composicion_gasto, v_ranking_cc CASCADE;
DROP TABLE IF EXISTS correccion_costo_unitario, costos_mensuales, produccion_mensual,
                     presupuesto_mensual, facturacion_mensual, centros_costo CASCADE;

CREATE TABLE centros_costo (
    id            SERIAL PRIMARY KEY,
    codigo        VARCHAR(40) UNIQUE NOT NULL,
    nombre        VARCHAR(120) NOT NULL,
    tipo          VARCHAR(20) NOT NULL
                  CHECK (tipo IN ('hospitalizacion','uti','ambulatorio','apoyo')),
    clasificacion VARCHAR(10) NOT NULL DEFAULT 'Final'
                  CHECK (clasificacion IN ('Final','Apoyo'))
);

CREATE TABLE costos_mensuales (
    id                SERIAL PRIMARY KEY,
    centro_costo_id   INTEGER NOT NULL REFERENCES centros_costo(id),
    periodo           DATE NOT NULL,
    recurso_humano    NUMERIC(16,2) NOT NULL DEFAULT 0,
    gastos_generales  NUMERIC(16,2) NOT NULL DEFAULT 0,
    insumos           NUMERIC(16,2) NOT NULL DEFAULT 0,
    costo_indirecto   NUMERIC(16,2) NOT NULL DEFAULT 0,
    costo_directo     NUMERIC(16,2) GENERATED ALWAYS AS (recurso_humano + gastos_generales + insumos) STORED,
    costo_total       NUMERIC(16,2) GENERATED ALWAYS AS (recurso_humano + gastos_generales + insumos + costo_indirecto) STORED,
    UNIQUE (centro_costo_id, periodo)
);

CREATE TABLE produccion_mensual (
    id                  SERIAL PRIMARY KEY,
    centro_costo_id     INTEGER NOT NULL REFERENCES centros_costo(id),
    periodo             DATE NOT NULL,
    egresos             INTEGER NOT NULL DEFAULT 0,   -- "produccion" SIGCOM: egresos en centros con cama; otra unidad (consultas, examenes) en el resto
    dias_cama_ocupados  INTEGER NOT NULL DEFAULT 0,   -- solo centros con cama
    camas_dotacion      INTEGER NOT NULL DEFAULT 0,
    UNIQUE (centro_costo_id, periodo)
);

-- Correcciones del hospital al costo unitario mensual (difieren del Cubo 9).
-- Si hay fila para (centro de costo, periodo), las vistas de abajo muestran este
-- valor en vez de costo_total / egresos (o / dias cama). Se cargan en 03_correcciones.sql,
-- aparte de los datos del Cubo, para que recargar un Excel nuevo no las pise.
CREATE TABLE correccion_costo_unitario (
    centro_costo_id   INTEGER NOT NULL REFERENCES centros_costo(id),
    periodo           DATE NOT NULL,
    costo_por_egreso  NUMERIC(16,2),
    costo_por_dco     NUMERIC(16,2),
    nota              TEXT,
    PRIMARY KEY (centro_costo_id, periodo)
);

-- ---- Vistas de KPI (las consulta Grafana) --------------------------------

-- Paneles 1-3: KPI de hospitalizacion. Se filtran por tipo en el panel
-- (solo 'hospitalizacion' y 'uti' tienen egresos + dias cama con sentido).
CREATE VIEW v_costo_por_egreso AS
SELECT cc.nombre AS metric, cc.tipo, cm.periodo,
       COALESCE(k.costo_por_egreso,
                CASE WHEN pm.egresos > 0 THEN ROUND(cm.costo_total / pm.egresos, 0) END) AS costo_por_egreso
FROM costos_mensuales cm
JOIN produccion_mensual pm ON pm.centro_costo_id = cm.centro_costo_id AND pm.periodo = cm.periodo
JOIN centros_costo cc ON cc.id = cm.centro_costo_id
LEFT JOIN correccion_costo_unitario k ON k.centro_costo_id = cm.centro_costo_id AND k.periodo = cm.periodo;

CREATE VIEW v_costo_por_dco AS
SELECT cc.nombre AS metric, cc.tipo, cm.periodo,
       COALESCE(k.costo_por_dco,
                CASE WHEN pm.dias_cama_ocupados > 0 THEN ROUND(cm.costo_total / pm.dias_cama_ocupados, 0) END) AS costo_por_dco
FROM costos_mensuales cm
JOIN produccion_mensual pm ON pm.centro_costo_id = cm.centro_costo_id AND pm.periodo = cm.periodo
JOIN centros_costo cc ON cc.id = cm.centro_costo_id
LEFT JOIN correccion_costo_unitario k ON k.centro_costo_id = cm.centro_costo_id AND k.periodo = cm.periodo;

-- Egresos / dias cama "efectivos": los del Cubo, salvo en los meses con correccion, donde son
-- costo_total / costo unitario corregido. Los usan las tablas que agregan (Σ costo ÷ Σ egresos)
-- para que coincidan con las vistas mensuales de arriba.
CREATE VIEW v_produccion_efectiva AS
SELECT pm.centro_costo_id, pm.periodo, pm.egresos, pm.dias_cama_ocupados,
       CASE WHEN k.costo_por_egreso > 0 THEN cm.costo_total / k.costo_por_egreso ELSE pm.egresos END AS egresos_ef,
       CASE WHEN k.costo_por_dco > 0 THEN cm.costo_total / k.costo_por_dco ELSE pm.dias_cama_ocupados END AS dco_ef
FROM produccion_mensual pm
JOIN costos_mensuales cm ON cm.centro_costo_id = pm.centro_costo_id AND cm.periodo = pm.periodo
LEFT JOIN correccion_costo_unitario k ON k.centro_costo_id = pm.centro_costo_id AND k.periodo = pm.periodo;

CREATE VIEW v_alos AS
SELECT cc.nombre AS metric, cc.tipo, pm.periodo,
       CASE WHEN pm.egresos > 0 THEN ROUND(pm.dias_cama_ocupados::NUMERIC / pm.egresos, 2) END AS alos
FROM produccion_mensual pm
JOIN centros_costo cc ON cc.id = pm.centro_costo_id;

-- Panel 4: gasto total del hospital por mes.
-- OJO SIGCOM: el gasto real del hospital = suma de COSTOS DIRECTOS de los 36 CC.
-- El costo indirecto es el gasto de los CC de apoyo re-asignado a los finales
-- (no es plata nueva), por eso NO se suma aparte a nivel hospital.
CREATE VIEW v_gasto_hospital AS
SELECT cm.periodo,
       SUM(cm.recurso_humano)   AS recurso_humano,
       SUM(cm.gastos_generales) AS gastos_generales,
       SUM(cm.insumos)          AS insumos,
       SUM(cm.costo_directo)    AS costo_total
FROM costos_mensuales cm
GROUP BY cm.periodo;

-- Panel 5: composicion del gasto (% de RH / GG / Insumos sobre el total, suman 100).
CREATE VIEW v_composicion_gasto AS
SELECT periodo,
       ROUND(100 * recurso_humano   / NULLIF(costo_total,0), 1) AS pct_recurso_humano,
       ROUND(100 * gastos_generales / NULLIF(costo_total,0), 1) AS pct_gastos_generales,
       ROUND(100 * insumos          / NULLIF(costo_total,0), 1) AS pct_insumos
FROM v_gasto_hospital;

-- Panel 6: ranking de centros de costo por costo total acumulado (convencion Cubo 9).
-- El % se calcula solo sobre los CC finales (su suma == gasto total del hospital,
-- porque absorben todo el costo indirecto); en los CC de apoyo el % va NULL.
CREATE VIEW v_ranking_cc AS
SELECT cc.nombre AS metric, cc.tipo, cc.clasificacion,
       SUM(cm.costo_total)           AS costo_total_acum,
       ROUND(AVG(cm.costo_total), 0) AS costo_total_prom_mes,
       CASE WHEN cc.clasificacion = 'Final' THEN ROUND(
            100 * SUM(cm.costo_total) /
            NULLIF(SUM(SUM(cm.costo_total)) FILTER (WHERE cc.clasificacion = 'Final') OVER (), 0),
            2) END AS pct_del_gasto
FROM costos_mensuales cm
JOIN centros_costo cc ON cc.id = cm.centro_costo_id
GROUP BY cc.nombre, cc.tipo, cc.clasificacion;

-- ---- Vistas de produccion / ocupacion (paneles 7-10) --------------------

-- Ocupacion e indice de rotacion (giro cama) por centro de costo y mes.
-- indice ocupacional = DCO / (camas dotacion * dias del mes).  Puede pasar
-- de 100% cuando la demanda supera la dotacion asignada al servicio
-- (pacientes en exceso / boarding) -> es un hallazgo, no un error.
CREATE VIEW v_ocupacion_camas AS
SELECT cc.nombre AS metric, cc.tipo, pm.periodo,
       EXTRACT(DAY FROM (date_trunc('month', pm.periodo) + INTERVAL '1 month' - INTERVAL '1 day'))::int AS dias_mes,
       pm.camas_dotacion,
       pm.dias_cama_ocupados,
       pm.egresos,
       pm.camas_dotacion * EXTRACT(DAY FROM (date_trunc('month', pm.periodo) + INTERVAL '1 month' - INTERVAL '1 day'))::int AS dias_cama_disponibles,
       CASE WHEN pm.camas_dotacion > 0 THEN ROUND(
            100.0 * pm.dias_cama_ocupados
            / (pm.camas_dotacion * EXTRACT(DAY FROM (date_trunc('month', pm.periodo) + INTERVAL '1 month' - INTERVAL '1 day'))::int),
            1) END AS ocupacion_pct,
       CASE WHEN pm.camas_dotacion > 0 THEN ROUND(pm.egresos::numeric / pm.camas_dotacion, 2) END AS giro_cama
FROM produccion_mensual pm
JOIN centros_costo cc ON cc.id = pm.centro_costo_id;

-- Produccion y ocupacion agregada del hospital (6 hospitalizacion + UTI).
CREATE VIEW v_produccion_hospital AS
SELECT pm.periodo,
       SUM(pm.egresos)            AS egresos,
       SUM(pm.dias_cama_ocupados) AS dias_cama_ocupados,
       SUM(pm.camas_dotacion)     AS camas_dotacion,
       ROUND(100.0 * SUM(pm.dias_cama_ocupados)
             / NULLIF(SUM(pm.camas_dotacion) * EXTRACT(DAY FROM (date_trunc('month', pm.periodo) + INTERVAL '1 month' - INTERVAL '1 day'))::int, 0),
             1) AS ocupacion_pct
FROM produccion_mensual pm
JOIN centros_costo cc ON cc.id = pm.centro_costo_id
WHERE cc.tipo IN ('hospitalizacion','uti')
GROUP BY pm.periodo;
