A Multidimensional Agent-Based Modeling and Simulation Framework for Urban Water Demand Forecast under Socioeconomic Inequality

This folder contains the files used to carry out the simulations in the article "A Multidimensional Agent-Based Modeling and Simulation Framework for Urban Water Demand Forecast under Socioeconomic Inequality".

Traditional aggregate models fail to capture complex interactions between spatial heterogeneity and human behavior in urban water demand forecasting. We present a multidimensional Agent-Based Model for Water Prediction (ABM-WP) framework to simulate neighborhood-scale water consumption dynamics under socioeconomic inequality data from Salvador, Brazil. A key contribution is the systematic analysis of multiple 18 configuration scenarios integrating the Environmentalist, Moderate, and Wasteful behavioral profiles with socioeconomic income growth and population expansion. ABM-WP on the GAMA platform was compared to statistical seasonal ARIMA and machine learning models (LSTM, MLP, SVR). ANOVA and Tukey tests revealed significant tipping points where socioeconomic catalysts cause demand to deviate from historical trends over 220,000 m³ annually. ABM-WP identifies critical peaks that data-based methods fail to predict. Spatial consumption patterns analysis is driven by connection density and socioeconomic clustering. ABM-WP is a robust decision-support tool for governance, providing insights for urban sustainability targeting conservation and infrastructure planning.


The main project folders and their objectives are described below:

figuras - Contains graphs, tables, and figures generated for information analysis and scenario simulations.
includes - Contains CSV files with anonymized data used for simulation, as well as data transformed by analysis processes, such as preprocessing and profile classification.
modelos IA - This folder contains the scripts used to implement the statistical (SARIMA) and machine learning (LSTM, SVM, and SVM) models used for comparison with ABM-WP.
models - The simulation model implemented on the GAMA platform, using the GAML language, is located in this folder.
Python - Several scripts were developed and saved in this folder, from the code necessary for coordinate conversion to the code used for statistical tests of the results, as well as the scripts used to generate graphs and figures.
resultados - This folder contains the files generated as a result of the simulations and scenario analysis, files generated in csv, excel, and pdf formats.
sup - This folder contains a supplementary material, including loading video demonstrating the scenario simulation run on the GAMA platform.

To reproduce the simulation, simply access the subfolder named "includes", open the readmine.docx file, and follow the execution of the scripts from step 1 to 9. Steps 1 to 8 should be executed in Python, and file 9 should be executed using the GAMA platform.

Files 10 through 29 are Python scripts used for analyzing the results and generating figures and graphs to visualize the scenarios.

Alternatively, if you only want to run the simulation, simply open script 9 on the GAMA Platform, check the path to the source files used, and run the simulation.

