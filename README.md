# ABM-WP Framework: Agent-Based Model for Water Prediction

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GAMA Platform](https://img.shields.io/badge/GAMA-Platform-orange)](https://gama-platform.org/)
[![Python](https://img.shields.io/badge/Python-3.8+-green.svg)](https://www.python.org/)

## Overview

This repository contains the complete implementation of the **Agent-Based Model for Water Prediction (ABM-WP)** framework, developed for the article:

> *"A Multidimensional Agent-Based Modeling and Simulation Framework for Urban Water Demand Forecast"*

Water resource sustainability relies on the interplay of environmental, technological, and social factors shaping urban water demand. However, traditional aggregated water demand forecasting models often fail to capture spatio-temporal heterogeneity and behavioral dynamics of domestic water consumption.

The ABM-WP framework simulates neighborhood-scale water consumption considering income and population growth with three behavioral profiles:
- **Environmentalist** (low consumption)
- **Moderate** (average consumption)
- **Wasteful** (high consumption)

The model was implemented on the **GAMA platform**, tested and calibrated using historical data (2015-2025) from Salvador, Brazil, to generate future scenario analyses for 2026–2035, compared with statistical and machine learning models.

### Key Findings

- ANOVA and Tukey tests established that the environmentalist scenario (CII) differed significantly from the baseline (p-value = 0.0421) with projected consumption reductions of **48,494 m³/year**
- Heatmap analysis revealed the influence of connection density and socioeconomic dynamics on consumption patterns
- Results indicate that ABM-WP can contribute to decision support for urban water sustainability

---

## Repository Structure

ABM-WP/
├── models/
│ └── ABMSWPSimulacao.gaml # Main GAMA model file
├── includes/
│ ├── dados/ # Input data directory
│ │ ├── Tabela_consumo_Itapua_120m.csv # 120-month household consumption data
│ │ ├── Tabela_Subcategoria_Tarifaria.csv # Tariff category classification
│ │ ├── Tabela_Coord_Mat.csv # Anonymized geographic coordinates
│ │ └── Tabela_Consumidores_Itapua_2015_2025_full.csv # Consumer list (2015-2025)
│ ├── maps/ # GIS shapefiles
│ │ ├── Itapua13.shp # Itapuã census sectors
│ │ └── LIMITE_BAIRRO.shp # Salvador neighborhood boundaries
│ ├── Agregados_por_setores_renda_responsavel_BR.csv # Income by census sector (IBGE 2022)
│ └── README.pdf # Detailed Python script documentation
├── resultados/ # Simulation output directory
└── Python/ # Data preparation and analysis scripts
├── Python-prepara-simulacao-2015/
│ └── _Script_prepara_simulacao.ipynb
├── Python-analisa-resultado-simulacao-2015/
│ └── _Script_analisa_resultado_simulacao.ipynb
├── Python-prepara-simulacao/
│ └── _Script_prepara_simulacao.ipynb
└── Python-analisa-resultado-simulacao/
└── _Script_analisa_resultado_simulacao.ipynb

> **Note:** The following files exceed GitHub's 50 MB size limit and must be extracted manually:
> - `/includes/ibge_censo2022/Agregados_por_setores_caracteristicas_domicilio1_BR.zip`
> - `/includes/dados/Tabela_Coord_Mat.zip`
> - `/includes/dados/Tabela_consumo_Itapua_120m.zip`

## Prerequisites

### Required Software

| Software | Version | Download Link |
|----------|---------|---------------|
| **GAMA Platform** | 1.9.x (or latest) | [https://gama-platform.org/download](https://gama-platform.org/download) |
| **Python** | 3.8+ | [https://www.python.org/downloads/](https://www.python.org/downloads/) |
| **Jupyter Notebook** | Latest | `pip install notebook` |

### Python Dependencies

```bash
pip install pandas numpy matplotlib seaborn scikit-learn statsmodels