-- Correcciones al Cubo 9 entregadas por el hospital (bloques corregidos del Cubo).
-- Se aplican despues de 01_schema.sql y 02_data.sql. Temporal: se pueden quitar cuando
-- Dashboard_SIGCOM.xlsx se regenere con los Cubo 9 corregidos.

-- Enero 2026, HOSPITALIZACION GINECOLOGIA: Recurso Humano 57.960.744 e Indirectos 32.608.604
-- (Gastos Generales, Insumos, egresos y dias cama no cambian). Total general 102.771.542.
UPDATE costos_mensuales
SET recurso_humano = 57960744, costo_indirecto = 32608604
WHERE periodo = DATE '2026-01-01'
  AND centro_costo_id = (SELECT id FROM centros_costo WHERE codigo = 'HOSPITALIZACION_GINECOLOGIA');
