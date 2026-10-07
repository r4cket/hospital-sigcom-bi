-- Ajustes manuales a HOSPITALIZACION GINECOLOGIA, ene y mar 2026. NO reproducen el Cubo 9 exportado
-- de SIGCOM; el tablero lo indica en el titulo de la seccion de costo unitario.
-- Se aplican despues de 01_schema.sql y 02_data.sql. Gastos Generales, egresos y dias cama no cambian.
-- Para volver al Cubo: borrar este archivo y recargar 01 + 02.

-- Enero 2026: Recurso Humano 74.929.729, Insumos 3.022.708, Indirectos 3.407.440 (suma de sus items;
-- el bloque muestra 3.407.441). Total 83.010.940 -> 5.929.353 por egreso y 2.862.446 por dia cama
-- (el "Costo por Produccion 2" del bloque, 4.202.218, es el del Cubo original y no se recalculo).
UPDATE costos_mensuales
SET recurso_humano = 74929729, insumos = 3022708, costo_indirecto = 3407440
WHERE periodo = DATE '2026-01-01'
  AND centro_costo_id = (SELECT id FROM centros_costo WHERE codigo = 'HOSPITALIZACION_GINECOLOGIA');

-- Marzo 2026: Recurso Humano 81.061.983, Insumos 9.354.626, Indirectos 3.062.303.
-- Total 94.942.463 -> 3.955.936 por egreso y 1.265.900 por dia cama.
UPDATE costos_mensuales
SET recurso_humano = 81061983, insumos = 9354626, costo_indirecto = 3062303
WHERE periodo = DATE '2026-03-01'
  AND centro_costo_id = (SELECT id FROM centros_costo WHERE codigo = 'HOSPITALIZACION_GINECOLOGIA');
