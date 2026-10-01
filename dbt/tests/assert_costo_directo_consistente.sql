-- La columna generada costo_directo debe ser exactamente RH + GG + Insumos.
-- Si falla, alguien toco la tabla a mano o la carga entro mal.
select id
from {{ source("sigcom", "costos_mensuales") }}
where round(costo_directo, 2) <> round(recurso_humano + gastos_generales + insumos, 2)
