# Índices espectrales como predictores del carbono orgánico del suelo en modelos de *machine learning*: revisión sistemática y metaanálisis

Datos y código de la revisión sistemática (PRISMA 2020) y del metaanálisis sobre el uso de índices espectrales (NDVI, SAVI, MSAVI, OSAVI, EVI, NDMI, LSWI, BSI/Brightness y Tasseled Cap) como covariables de modelos de *machine learning* para predecir el carbono orgánico del suelo (COS).

*Spectral indices as predictors of soil organic carbon in machine learning models: a systematic review and meta-analysis. Data and code.*

## Autores

Dina Maribel Yana Yucra, Leonardo Sebastián Grimaldos Ávila, Maycol Jhonathan Chacca Charca, Jhoel Edu Cauna Huanca y Kewin Anthony Espinoza Hanco. Escuela Profesional de Ingeniería Estadística e Informática, Universidad Nacional del Altiplano, Puno, Perú.

## Contenido

| Ruta | Descripción |
|---|---|
| `datos/estudios_revision.csv` | Base de extracción de los 284 estudios que pasaron a texto completo (158 incluidos, 65 excluidos y 61 no recuperados). |
| `datos/busqueda_scopus.txt` | Ecuación de búsqueda, fecha y número de registros. |
| `R/metaanalisis.R` | Metaanálisis de efectos aleatorios del R² de validación. |
| `resultados/` | Resultados del metaanálisis (global, subgrupos, metarregresión, sensibilidad y sesgo de publicación). |
| `figuras/` | Gráfico de bosque por estudio, gráfico de embudo y metarregresión por tamaño de validación. |

## Reproducir el análisis

Requiere R (≥ 4.3) y los paquetes `metafor` y `openxlsx`. Desde la raíz del repositorio:

```r
install.packages(c("metafor", "openxlsx"))
```

```sh
Rscript R/metaanalisis.R
```

El script regenera `resultados/` y `figuras/`. Resultado principal: R² combinado = 0,69 (IC 95 %: 0,65–0,72; k = 133; I² = 99,0 %).

## Método en breve

- **Efecto:** R² de validación del mejor modelo de *machine learning* de cada estudio, transformado a r = √R² y a z de Fisher, con varianza 1/(n − 3), donde n es el tamaño del conjunto de validación.
- **Modelo:** efectos aleatorios con REML y ajuste de Knapp-Hartung (`metafor`).
- **Moderadores:** algoritmo, sensor, uso de suelo, tipo de métrica, riesgo de sesgo, año y log(n de validación).
- **Sensibilidad:** sin riesgo de sesgo alto, solo riesgo bajo, solo n de validación reportado, solo validación independiente, sin COS medido por combustión y sin estudios influyentes.
- **Sesgo de publicación:** prueba de Egger y *trim-and-fill*.

## Diccionario de datos (`datos/estudios_revision.csv`)

| Columna | Descripción |
|---|---|
| `ID` | Identificador del estudio (R001–R284). |
| `Autor (año)`, `Año`, `País`, `Título`, `Autores`, `Revista`, `DOI`, `Tipo de acceso` | Datos bibliográficos (Scopus). `País`: área de estudio o, si no se indica, afiliación del primer autor. |
| `Etapa PRISMA`, `Clasificación`, `Motivo de exclusión` | Resultado de la selección. Motivos: E2 otra variable respuesta; E3 espectroscopía sin imagen; E4 sin índice espectral como predictor; I4 sin modelo de *machine learning*. |
| `Revisado texto completo` | `Sí` si se evaluó el texto completo; `No (sin PDF)` si no se pudo recuperar (en ese caso los datos provienen del resumen). |
| `Variable respuesta`, `Sitio`, `Uso de suelo`, `Sensor`, `Índices`, `Otros índices`, `Algoritmo ML` | Características del estudio. |
| `Mejor modelo`, `R²`, `RMSE`, `Unidad RMSE` | Mejor modelo de *machine learning* y sus métricas de validación. |
| `Validación`, `n de puntos`, `Área`, `Profundidad` | Esquema de validación y muestreo. |
| `<familia> Evaluado` / `<familia> Retenido` | Para NDVI, SAVI, MSAVI, OSAVI, EVI, NDMI, LSWI, BSI y TC: si el índice fue covariable candidata y si quedó en el modelo final (`Sí`, `No`, `ND`). |
| `R² mejor con índices`, `RMSE mejor con índices` | Métricas del mejor modelo que contiene al menos un índice evaluado. |
| `n validación`, `Origen n validación` | Tamaño del conjunto de validación; `reportado` o `derivado` de la partición (hold-out a/b: n × b %; k-fold o LOOCV: n total). |
| `Tipo de métrica`, `Fuga de datos`, `n < 50`, `Riesgo de sesgo`, `Justificación riesgo` | Evaluación del riesgo de sesgo (PROBAST adaptado). |
| `Importancia de índices`, `Cambio sin índices`, `Regla aplicada`, `Notas revisión` | Notas de la extracción y reglas de aplicación de los criterios (R1–R6). |

`ND`: no disponible o no reportado.

## Licencia

Código bajo licencia MIT (`LICENSE`). Datos bajo licencia [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Los textos completos de los artículos revisados no se incluyen por derechos de autor.
