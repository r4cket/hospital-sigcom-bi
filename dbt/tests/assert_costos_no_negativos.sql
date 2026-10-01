-- Ningun componente de costo puede ser negativo.
select id
from {{ source("sigcom", "costos_mensuales") }}
where recurso_humano < 0
   or gastos_generales < 0
   or insumos < 0
   or costo_indirecto < 0
