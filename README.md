# ABM-WP Framework: Agent-Based Model for Water Prediction

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

> **Note:** The following files exceed GitHub's 50 MB size limit and must be extracted manually:
> - `/includes/ibge_censo2022/Agregados_por_setores_caracteristicas_domicilio1_BR.zip`
> - `/includes/dados/Tabela_Coord_Mat.zip`
> - `/includes/dados/Tabela_consumo_Itapua_120m.zip`

## Prerequisites

### Required Software

| Software | Version | Download Link |
|----------|---------|---------------|
| **GAMA Platform** | 1.9.x (or latest) | [https://gama-platform.org/download](https://gama-platform.org/download) |
| **Python** | 3.13+ | [https://www.python.org/downloads/](https://www.python.org/downloads/) |
| **Jupyter Notebook** | Latest | `pip install notebook` |

### Python Dependencies

```bash
pip install pandas numpy matplotlib seaborn scikit-learn statsmodels