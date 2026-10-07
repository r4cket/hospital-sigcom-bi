-- Correcciones al Cubo 9 entregadas por el hospital (bloques corregidos del Cubo).
-- Se aplican despues de 01_schema.sql y 02_data.sql. Temporal: se pueden quitar cuando
-- Dashboard_SIGCOM.xlsx se regenere con los Cubo 9 corregidos.

-- Enero 2026, HOSPITALIZACION GINECOLOGIA: Recurso Humano 57.960.744 e Indirectos 32.608.604
-- (Gastos Generales, Insumos, egresos y dias cama no cambian). Total general 102.771.542.
UPDATE costos_mensuales
SET recurso_humano = 57960744, costo_indirecto = 32608604
WHERE periodo = DATE '2026-01-01'
  AND centro_costo_id = (SELECT id FROM centros_costo WHERE codigo = 'HOSPITALIZACION_GINECOLOGIA');

-- Marzo 2026, HOSPITALIZACION GINECOLOGIA: AJUSTE DEL HOSPITAL (no reproduce el Cubo 9 exportado).
-- Recurso Humano 81.061.983, Insumos 9.354.626, Indirectos 3.062.303 (Gastos Generales, egresos y
-- dias cama no cambian). Total general 94.942.463 -> 3.955.936 por egreso, 1.265.900 por dia cama.
-- El tablero lo indica (titulo de la seccion y descripciones de los paneles).
UPDATE costos_mensuales
SET recurso_humano = 81061983, insumos = 9354626, costo_indirecto = 3062303
WHERE periodo = DATE '2026-03-01'
  AND centro_costo_id = (SELECT id FROM centros_costo WHERE codigo = 'HOSPITALIZACION_GINECOLOGIA');
