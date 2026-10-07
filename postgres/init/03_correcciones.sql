-- Correcciones del hospital al costo unitario mensual (difieren del Cubo 9 SIGCOM).
-- Se cargan despues de 01_schema.sql y 02_data.sql; recargar un Excel nuevo regenera 02 pero no toca este archivo.
INSERT INTO correccion_costo_unitario (centro_costo_id, periodo, costo_por_egreso, costo_por_dco, nota)
SELECT id, DATE '2026-01-01', 3643978, 1020874, 'Corregido por el hospital; difiere del Cubo 9 SIGCOM'
FROM centros_costo WHERE codigo = 'HOSPITALIZACION_GINECOLOGIA'
UNION ALL
SELECT id, DATE '2026-03-01', 3883873, 989742, 'Corregido por el hospital; difiere del Cubo 9 SIGCOM'
FROM centros_costo WHERE codigo = 'HOSPITALIZACION_GINECOLOGIA';
