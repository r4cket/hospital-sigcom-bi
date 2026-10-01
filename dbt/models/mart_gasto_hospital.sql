{{ config(materialized="view") }}

-- Gasto real del hospital por mes = suma de COSTOS DIRECTOS de los 36 CC.
-- (RH + GG + Insumos). El costo indirecto es gasto de los CC de apoyo
-- re-asignado a los finales; no es plata nueva, por eso no se suma aparte.

select
    cm.periodo,
    sum(cm.recurso_humano)                                       as recurso_humano,
    sum(cm.gastos_generales)                                     as gastos_generales,
    sum(cm.insumos)                                              as insumos,
    sum(cm.recurso_humano + cm.gastos_generales + cm.insumos)    as costo_total
from {{ source("sigcom", "costos_mensuales") }} cm
group by cm.periodo
