# ============================================================
# 1. PACCHETTI NECESSARI
# ============================================================
library(readxl)
library(dplyr)
library(ggplot2)
library(cluster)
library(factoextra)

# ============================================================
# 2. CARICAMENTO DEL DATASET
# ============================================================
# Leggiamo il foglio specifico dell'esercitazione
nome_file <- "Portafoglio_Prestiti_PMI_Cluster_Analysis.xlsx"

imprese <- read_excel(nome_file, sheet = "Portafoglio_Prestiti")
imprese <- as.data.frame(imprese)

# Controllo rapido: stampa numero di righe e colonne
cat("Righe:", nrow(imprese), "- Colonne:", ncol(imprese), "\n")

# 2. CARICAMENTO DEL DATASET TRAMITE FILE CHOOSER
# ============================================================

imprese <- read_excel(file.choose(), sheet = "Portafoglio_Prestiti")
imprese <- as.data.frame(imprese)

# ============================================================
# 3. SELEZIONE DELLE 8 VARIABILI DEL MODELLO
# ============================================================

indicatori <- imprese[, c(
  "crescita_fatturato_pct",
  "ebitda_margin_pct",
  "roa_pct",
  "current_ratio",
  "debt_equity",
  "dscr",
  "utilizzo_affidamenti_pct",
  "giorni_ritardo_medi"
)]

# Verifica che non ci siano valori mancanti
cat("Valori mancanti:\n")
print(colSums(is.na(indicatori)))

# ============================================================
# 4. STANDARDIZZAZIONE DEI DATI (Z-SCORE)
# ============================================================

indicatori_std <- scale(indicatori)
rownames(indicatori_std) <- imprese$id_cliente

# ============================================================
# 5. METODO DEL GOMITO (ELBOW METHOD - WSS)
# ============================================================

set.seed(123)

grafico_gomito <- fviz_nbclust(
  indicatori_std,
  FUNcluster = kmeans,
  method = "wss",
  k.max = 8,
  nstart = 25
)

# Mostra il grafico
grafico_gomito

# ============================================================
# 6. CAMPIONE RAPPRESENTATIVO PER LA SILHOUETTE (N = 500)
# ============================================================
# Il calcolo della matrice di distanze su 10.000 righe richiede eccessiva memoria.
# Utilizziamo un campione casuale riproducibile di 500 imprese.

set.seed(123)
righe_campione <- sample(1:nrow(indicatori_std), size = 500)
indicatori_sil <- indicatori_std[righe_campione, ]
distanze_sil <- dist(indicatori_sil)

# ============================================================
# 7. ADDESTRAMENTO MODELLO FINALE K = 4
# ============================================================
set.seed(123)
modello_k4 <- kmeans(indicatori_std, centers = 4, nstart = 25)

# Aggiunta del cluster assegnato al dataset
imprese$cluster_4 <- modello_k4$cluster

# Calcolo Silhouette media per K = 4
sil_k4 <- cluster::silhouette(modello_k4$cluster[righe_campione], distanze_sil)
cat("Silhouette Media (K = 4):", round(mean(sil_k4[, "sil_width"]), 3), "\n")

# ============================================================
# 8. DENOMINAZIONE MANAGERIALE DEI 4 PROFILI
# ============================================================
nomi_profili <- c(
  "Solide e liquide",
  "In crescita con credito intensivo",
  "Indebitate e vulnerabili",
  "In deterioramento"
)

imprese$profilo_cluster <- factor(imprese$cluster_4, levels = 1:4, labels = nomi_profili)

# Numerosità e quote percentuali per profilo
table(imprese$profilo_cluster)
round(prop.table(table(imprese$profilo_cluster)) * 100, 1)

# ============================================================
# 9. MAPPA VISIVA DEI CLUSTER (PRIME 2 COMPONENTI PCA)
# ============================================================
grafico_cluster <- fviz_cluster(
  modello_k4,
  data = indicatori_std,
  geom = "point",
  ellipse = TRUE,
  show.clust.cent = TRUE,
  main = "Segmentazione Creditizia Portafoglio PMI (K = 4)"
) +
  ggplot2::scale_color_discrete(name = "Profilo", labels = nomi_profili) +
  ggplot2::scale_fill_discrete(name = "Profilo", labels = nomi_profili)

grafico_cluster

# ============================================================
# 10. TABELLA DI SINTESI MANAGERIALE & VALIDAZIONE EX-POST
# ============================================================

sintesi_manageriale <- aggregate(
  imprese[, c(
    "crescita_fatturato_pct",
    "ebitda_margin_pct",
    "roa_pct",
    "current_ratio",
    "debt_equity",
    "dscr",
    "utilizzo_affidamenti_pct",
    "giorni_ritardo_medi",
    "probabilita_default_12m_pct",
    "debito_residuo_eur"
  )],
  by = list(Profilo = imprese$profilo_cluster),
  FUN = mean
)

# Arrotondamento
sintesi_manageriale[, 2:10] <- round(sintesi_manageriale[, 2:10], 2)
sintesi_manageriale[, 11] <- round(sintesi_manageriale[, 11], 0)

# Aggiunta numerosità e peso %
sintesi_manageriale$Imprese <- as.vector(table(imprese$profilo_cluster))
sintesi_manageriale$Peso_pct <- round(sintesi_manageriale$Imprese / nrow(imprese) * 100, 1)

# Riorganizzazione colonne
sintesi_manageriale <- sintesi_manageriale[, c("Profilo", "Imprese", "Peso_pct", 
                                               "crescita_fatturato_pct", "ebitda_margin_pct", 
                                               "roa_pct", "current_ratio", "debt_equity", 
                                               "dscr", "probabilita_default_12m_pct", "debito_residuo_eur")]

print(sintesi_manageriale)

# ============================================================
# 11. SALVATAGGIO DEI GRAFICI PER GITHUB
# ============================================================

ggsave("elbow_plot.png", plot = grafico_gomito, width = 8, height = 5, dpi = 300)
ggsave("cluster_map.png", plot = grafico_cluster, width = 9, height = 6, dpi = 300)