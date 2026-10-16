# Metaanálisis: desempeño (R² de validación) de modelos de ML para COS/SOM con índices espectrales
# Efecto: r = sqrt(R²) -> z de Fisher; varianza 1/(n_validación - 3)
# Modelo de efectos aleatorios (REML) con ajuste de Knapp-Hartung
# Uso (desde la raíz del repositorio): Rscript R/metaanalisis.R

suppressMessages({library(metafor); library(openxlsx)})

x <- read.csv("datos/estudios_revision.csv", colClasses = "character", check.names = FALSE,
              encoding = "UTF-8", na.strings = "")
dir.create("resultados", showWarnings = FALSE); dir.create("figuras", showWarnings = FALSE)

num <- function(v) suppressWarnings(as.numeric(v))
d <- subset(x, `Clasificación` == "Incluir" & `Revisado texto completo` == "Sí")
d$R2 <- num(d$`R²`)
d$n_val <- num(d$`n validación`)
d <- subset(d, !is.na(R2) & R2 >= 0 & R2 < 1 & !is.na(n_val) & n_val > 3)

# ---- tamaño del efecto
d$yi <- atanh(sqrt(d$R2))
d$vi <- 1 / (d$n_val - 3)
d$Año <- num(d$`Año`)

# ---- moderadores categóricos
cat_modelo <- function(m) {
  m <- tolower(ifelse(is.na(m), "", m))
  if (grepl("stack|ensemble|ensamble|híbrid|hybrid|\\+ *kriging|rfrk|rk\\b", m)) return("Ensamble/híbrido")
  if (grepl("xgb|gbm|gbr|gbt|boost|catboost|lgbm|lightgbm", m)) return("Boosting")
  if (grepl("cubist", m)) return("Cubist")
  if (grepl("svm|svr", m)) return("SVM")
  if (grepl("cnn|ann|dnn|bpnn|mlp|lstm|deep|neural|tabpfn|transformer|red", m)) return("ANN/DL")
  if (grepl("\\brf\\b|random forest|qrf|quantile regression forest|rfr", m)) return("RF")
  "Otro/ND"
}
d$Modelo <- factor(sapply(d$`Mejor modelo`, cat_modelo))

cat_sensor <- function(s) {
  s <- ifelse(is.na(s), "", s)
  k <- c("Sentinel-2", "Landsat", "MODIS", "UAV")
  hit <- k[sapply(k, function(z) grepl(z, s, fixed = TRUE))]
  if (length(hit) == 1 && !grepl("Otro", s)) return(hit)
  if (length(hit) == 0) return("Otro/ND")
  "Varios sensores"
}
d$Sensor <- factor(sapply(d$Sensor, cat_sensor))

cat_uso <- function(u) {
  u <- ifelse(is.na(u), "", u)
  if (grepl(",", u)) return("Mixto")
  if (u %in% c("Agrícola", "Forestal", "Pastizal", "Humedal", "Árido/desierto")) return(u)
  "Mixto/ND"
}
d$Uso <- factor(sapply(d$`Uso de suelo`, cat_uso))
d$Metrica <- factor(d$`Tipo de métrica`)
d$Riesgo <- factor(d$`Riesgo de sesgo`, levels = c("Bajo", "Poco claro", "Alto"))
d$OrigenN <- ifelse(d$`Origen n validación` == "reportado", "reportado", "derivado")
fam <- c("NDVI", "SAVI", "MSAVI", "OSAVI", "EVI", "NDMI", "LSWI", "BSI", "TC")
for (f in fam) d[[paste0(f, "_ret")]] <- as.integer(d[[paste0(f, " Retenido")]] %in% "Sí")
d$etiqueta <- paste0(d$ID, " ", d$`Autor (año)`)

z2R2 <- function(z) tanh(z)^2
resumen <- function(m, nombre) {
  p <- predict(m)
  data.frame(Análisis = nombre, k = m$k,
             R2 = z2R2(p$pred), IC_inf = z2R2(p$ci.lb), IC_sup = z2R2(p$ci.ub),
             IP_inf = z2R2(max(p$pi.lb, 0)), IP_sup = z2R2(p$pi.ub),
             z = m$b[1], tau2 = m$tau2, I2 = m$I2, Q = m$QE, p_Q = m$QEp)
}

# ---- 1. modelo global
m0 <- rma(yi, vi, data = d, method = "REML", test = "knha", slab = etiqueta)

# ---- 2. subgrupos y metarregresión (cada moderador por separado)
mods <- list(Modelo = ~ Modelo, Sensor = ~ Sensor, `Uso de suelo` = ~ Uso,
             `Tipo de métrica` = ~ Metrica, `Riesgo de sesgo` = ~ Riesgo,
             `Año` = ~ Año, `log(n validación)` = ~ log(n_val))
sub <- list(); mr <- list()
for (nm in names(mods)) {
  mm <- rma(yi, vi, mods = mods[[nm]], data = d, method = "REML", test = "knha")
  mr[[nm]] <- data.frame(Moderador = nm, k = mm$k, F = mm$QM, gl1 = mm$QMdf[1], gl2 = mm$QMdf[2],
                         p = mm$QMp, R2_het = mm$R2, I2_residual = mm$I2)
  v <- all.vars(mods[[nm]])
  if (is.factor(d[[v]])) for (lv in levels(droplevels(d[[v]]))) {
    dd <- d[d[[v]] == lv & !is.na(d[[v]]), ]
    if (nrow(dd) >= 3) sub[[length(sub) + 1]] <- cbind(Moderador = nm, Nivel = lv,
      resumen(rma(yi, vi, data = dd, method = "REML", test = "knha"), lv))
    else sub[[length(sub) + 1]] <- data.frame(Moderador = nm, Nivel = lv, Análisis = lv, k = nrow(dd))
  }
}
sub <- do.call(rbind, lapply(sub, function(s) { s[setdiff(names(sub[[1]]), names(s))] <- NA; s[names(sub[[1]])] }))
mr <- do.call(rbind, mr)

# ---- 3. índices retenidos: metarregresión conjunta y R² por familia
mi <- rma(yi, vi, mods = ~ NDVI_ret + SAVI_ret + EVI_ret + NDMI_ret + BSI_ret, data = d,
          method = "REML", test = "knha")
coef_ind <- data.frame(Término = rownames(mi$beta), b = mi$beta[, 1], se = mi$se, p = mi$pval,
                       IC_inf = mi$ci.lb, IC_sup = mi$ci.ub)

x$R2i <- num(x$`R² mejor con índices`); x$n_val <- num(x$`n validación`)
por_indice <- list()
for (f in fam) {
  dd <- subset(x, `Clasificación` == "Incluir" & x[[paste0(f, " Retenido")]] %in% "Sí" &
                 !is.na(R2i) & R2i >= 0 & R2i < 1 & !is.na(n_val) & n_val > 3)
  if (nrow(dd) >= 3) {
    dd$yi <- atanh(sqrt(dd$R2i)); dd$vi <- 1 / (dd$n_val - 3)
    por_indice[[f]] <- resumen(rma(yi, vi, data = dd, method = "REML", test = "knha"), f)
  } else por_indice[[f]] <- data.frame(Análisis = f, k = nrow(dd))
}
por_indice <- do.call(rbind, lapply(por_indice, function(s) { s[setdiff(names(resumen(m0, "")), names(s))] <- NA; s }))

# ---- 4. sensibilidad
cto <- c("R110", "R113", "R225")
sens <- rbind(
  resumen(m0, "Global (todos)"),
  resumen(update(m0, subset = Riesgo != "Alto"), "Sin riesgo Alto"),
  resumen(update(m0, subset = Riesgo == "Bajo"), "Solo riesgo Bajo"),
  resumen(update(m0, subset = OrigenN == "reportado"), "Solo n de validación reportado"),
  resumen(update(m0, subset = Metrica == "validación independiente"), "Solo validación independiente"),
  resumen(update(m0, subset = !(ID %in% cto)), "Sin COS por combustión (R110, R113, R225)"))
loo <- leave1out(m0)
inf <- influence(m0)
influyentes <- d$etiqueta[inf$is.infl]
sens <- rbind(sens, resumen(update(m0, subset = !inf$is.infl), "Sin estudios influyentes"))

# ---- 5. sesgo de publicación / estudios pequeños
eg <- regtest(m0, model = "rma", predictor = "sei")
m0_z <- rma(yi, vi, data = d, method = "REML")
tf <- trimfill(m0_z)
pub <- data.frame(Prueba = c("Egger (rma, predictor = EE)", "Trim-and-fill: estudios imputados",
                             "Trim-and-fill: R² ajustado"),
                  Valor = c(sprintf("z = %.2f; p = %.4f", eg$zval, eg$pval),
                            sprintf("%d (lado %s)", tf$k0, tf$side),
                            sprintf("%.3f [%.3f; %.3f]", z2R2(tf$b[1]), z2R2(tf$ci.lb), z2R2(tf$ci.ub))))

# ---- 6. figuras
png("figuras/forest_plot.png", width = 2400, height = 300 + 34 * nrow(d), res = 200)
forest(m0, order = "obs", transf = function(z) tanh(z)^2, refline = NA, xlab = "R² de validación",
       header = c("Estudio", "R² [IC 95 %]"), cex = 0.55, alim = c(0, 1), at = seq(0, 1, 0.2))
dev.off()
png("figuras/funnel_plot.png", width = 1600, height = 1300, res = 200)
funnel(tf, xlab = "z de Fisher (r = √R²)", legend = TRUE); dev.off()
png("figuras/bubble_n_validacion.png", width = 1600, height = 1300, res = 200)
regplot(rma(yi, vi, mods = ~ log(n_val), data = d, method = "REML", test = "knha"),
        xlab = "log(n de validación)", ylab = "z de Fisher", transf = NULL); dev.off()

# ---- 7. exportar
g <- resumen(m0, "Modelo global de efectos aleatorios")
datos <- d[, c("ID", "Autor (año)", "Año", "País", "Mejor modelo", "Modelo", "Sensor", "Uso",
               "Metrica", "Riesgo", "R2", "n_val", "OrigenN", "yi", "vi", paste0(fam, "_ret"))]
wb <- createWorkbook()
hojas <- list(Global = g, Subgrupos = sub, Metarregresión = mr, `Índices retenidos` = coef_ind,
              `R2 por índice` = por_indice, Sensibilidad = sens,
              `Leave-one-out` = cbind(Estudio = d$etiqueta, R2 = z2R2(loo$estimate), I2 = loo$I2),
              `Sesgo publicación` = pub, Datos = datos)
for (h in names(hojas)) { addWorksheet(wb, h); writeData(wb, h, hojas[[h]]) }
saveWorkbook(wb, "resultados/resultados_metaanalisis.xlsx", overwrite = TRUE)

sink("resultados/resumen_metaanalisis.txt")
cat("k =", m0$k, "estudios\n\n"); print(m0)
cat("\nR² combinado:", round(g$R2, 3), " IC95:", round(g$IC_inf, 3), "-", round(g$IC_sup, 3),
    " IP95:", round(g$IP_inf, 3), "-", round(g$IP_sup, 3), "\n")
cat("\nEstudios influyentes:", paste(influyentes, collapse = "; "), "\n")
cat("\nMetarregresión por moderador:\n"); print(mr, row.names = FALSE, digits = 3)
cat("\nÍndices retenidos (metarregresión conjunta):\n"); print(coef_ind, row.names = FALSE, digits = 3)
cat("\nR² por familia de índice (estudios que lo retienen):\n"); print(por_indice[, 1:7], row.names = FALSE, digits = 3)
cat("\nSensibilidad:\n"); print(sens[, 1:7], row.names = FALSE, digits = 3)
cat("\nSesgo de publicación:\n"); print(pub, row.names = FALSE)
sink()
