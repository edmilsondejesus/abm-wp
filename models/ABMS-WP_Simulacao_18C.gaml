model ABMSWPSimulacao

global {
	//This script generates the simulations and also saves the results individually by household and by scenario, including the new consumption profile for each scenario.

	//Path to the results file
    string path_qgis_export <- "../resultados/comparativo_perfil_cenarios_qgis.csv";

	// Variable to identify the current scenario (must be updated in the setup of each scenario)
    string scenario_id <- "CI"; 

	action inicializar_csv_qgis {
        save ["SK_MATRICULA", "CD_SETOR", "TP_COMPORTAMENTO", "NN_MEDIA_CONSUMO", "NN_CONSUMO_DIARIO", "NN_MORADORES_ANALISE","NM_CENARIO", "TP_NOVO_COMPORTAMENTO", "NN_NOVA_MEDIA_CONSUMO", "NN_NOVO_CONSUMO_DIARIO","NN_NOVO_MORADORES_ANALISE"] 
        to: path_qgis_export format: "csv" rewrite: true;
        
    }
    
    // Default values ​​if the file cannot be read.
    float limite_baixa_renda <- 2000.0; 
    float limite_alta_renda <- 5000.0;  
    float sensibilidade_renda <- 0.0001; 
    float intercepto_base <- 10.0;      

    // Path to the income parameters file
    string file_params <- "../includes/parametros_renda_calculados.csv";
    
    // Action to read the CSV of income parameters
    action carregar_parametros_renda {
        if (file_exists(file_params)) {
            csv_file arquivo_params <- csv_file(file_params, ";", true);
            matrix dados <- matrix(arquivo_params);
            
            loop i from: 0 to: dados.rows - 1 {
                string nome_param <- string(dados[0, i]);
                float valor_param <- float(dados[1, i]);
                
                if (nome_param = 'limite_baixa_renda') { limite_baixa_renda <- valor_param; }
                if (nome_param = 'limite_alta_renda') { limite_alta_renda <- valor_param; }
                if (nome_param = 'sensibilidade_renda') { sensibilidade_renda <- valor_param; }
                if (nome_param = 'intercepto_base') { intercepto_base <- valor_param; }
            }
            write "--- PARÂMETROS DE RENDA ---";
            write "Limite Baixa: " + limite_baixa_renda + " | Limite Alta: " + limite_alta_renda;
            write "Sensibilidade (k): " + sensibilidade_renda;
        } else {
            write "AVISO: Arquivo parametros_renda_calculados.csv não encontrado. Usando valores default.";
        }
    }
    
    
	// Path to the media file by profile
    string file_medias <- "../resultados/medias_consumo_por_perfil.csv";
    csv_file arquivo_medias <- csv_file(file_medias, ";", true);
    
     // Variables for storing averages
    float media_ambientalista <- 0.0;
    float media_perdulario <- 0.0;
    float media_moderado <- 0.0;
    
    // Conversion factor
    float fator_conversao_mensal <- 30.5 / 1000;
    
    // Global variables for counting residences
    int total_residencias <- 0;
    int total_ambientalistas <- 0;
    int total_perdularios <- 0;
    int total_moderados <- 0;
    int residencias_sem_consumo <- 0;
    int residencias_com_renda_padarao <-0;
    list<string> matriculas_sem_consumo <- [];
    
    // Historical data for temporal storage (represents monthly data)
    list<int> historico_total_residencias <- [];
    list<int> historico_ambientalistas <- [];
    list<int> historico_perdularios <- [];
    list<int> historico_moderados <- [];
    
    // Data file paths
    string file_path <- "../includes/Tabela_consumidores_Itapua_com_setor_comportamento_e_renda.csv";
    string consumo_file <- "../includes/Tabela_consumo_medio_Itapua_12m.csv";
    string shapefile_CD20220_path_prj <- "31984";
    file BA_setores_CD20220_shape_file <- shape_file("../includes/maps/Itapua13.shp", shapefile_CD20220_path_prj, true);

    // Initialization of CSV files
    csv_file arquivo <- csv_file(file_path, ";", true);
    csv_file arquivo_consumo <- csv_file(consumo_file, ";", true);    

    // Shapefile path
    string shapefile_path <- "../includes/maps/LIMITE_BAIRRO.shp";
    string shapefile_path_prj <- "31984";
    file shapefile <- shape_file(shapefile_path, shapefile_path_prj, true);
    geometry shape <- envelope(BA_setores_CD20220_shape_file);
        
    // Time variables and simulation
    int meses_simulacao <- 60;
    int ano_corrente <- 2025;
    int mes_corrente <- 1;
    list<int> anos <- [2025, 2026, 2027, 2028, 2029, 2030, 2031, 2032, 2033, 2034, 2035];
    
    // Growth rates (Monthly)
    list<float> taxas_crescimento_mensal <- [0.00025, 0.00023, 0.00020, 0.00018, 0.00016, 0.00014, 0.00012, 0.00009, 0.00007, 0.00004, 0.00001, -0.00001];
    
    // Vector of year-on-year income increase percentages (2025-2034)
    list<float> percentuais_aumento_renda <- [0.02, 0.025, 0.03, 0.028, 0.026, 0.024, 0.022, 0.02, 0.018, 0.016, 0.014];
    

    // Probabilidade de crescimento populacional aleatório (para cenários VII-IX)
    float probabilidade_crescimento_aleatorio <- 0.7; // 70% of homes will experience growth.
    
    //Consumption data by scenario (List of monthly totals)
    list<float> consumo_anual_total_cI <- [];
    list<float> consumo_anual_total_cII <- [];
    list<float> consumo_anual_total_cIII <- [];
    list<float> consumo_anual_total_cIV <- [];
    list<float> consumo_anual_total_cV <- [];
    list<float> consumo_anual_total_cVI <- [];
    list<float> consumo_anual_total_cVII <- [];
    list<float> consumo_anual_total_cVIII <- [];
    list<float> consumo_anual_total_cIX <- [];
    list<float> consumo_anual_total_cX <- [];
    list<float> consumo_anual_total_cXI <- [];
    list<float> consumo_anual_total_cXII <- [];
    list<float> consumo_anual_total_cXIII <- [];
    list<float> consumo_anual_total_cXIV <- [];
    list<float> consumo_anual_total_cXV <- [];
    list<float> consumo_anual_total_cXVI <- [];  // Pop Uniforme + Renda Aleatória Linear
    list<float> consumo_anual_total_cXVII <- []; // Pop Uniforme + Renda Aleatória Equilibrio
    list<float> consumo_anual_total_cXVIII <- []; // Pop Uniforme + Renda Aleatória Desequilibrio
    
    // Variables for communication between agents
    list<float> dados_processados <- [];
    list<float> previsoes_consumo <- [];
    list<float> relatorio_final <- [];
    
	map<string, float> map_consumo_real_12m <- [];

    // Function to load media
	action carregar_medias_arquivo {
        // Load the file as a generic data array.
        matrix dados_matrix <- matrix(arquivo_medias);

        // Loop for matrix lines
        loop i from: 0 to: dados_matrix.rows - 1 {
            
            
            string perfil_str <- string(dados_matrix[0, i]); 
            float consumo_val <- float(dados_matrix[1, i]);
    
            if (perfil_str contains "AMBIENTALISTA") {
                media_ambientalista <- consumo_val;
            } else if (perfil_str contains "PERDULARIO") {
                media_perdulario <- consumo_val;
            } else if (perfil_str contains "MODERADO") {
                media_moderado <- consumo_val;
            }
        }

        write "=== MÉDIA DE CONSUMO ===";
        write "Ambientalistas: " + media_ambientalista;
        write "Moderados: " + media_moderado;
        write "Perdulários: " + media_perdulario;

        if (media_ambientalista = 0.0 or media_perdulario = 0.0) {
            error "ERRO CRÍTICO: Os valores de consumo continuam 0.0. Verifique se o separador do CSV é mesmo ponto e vírgula (;).";
        }
    }
    init {  
        // Load means from file
        do carregar_medias_arquivo;
       	do carregar_parametros_renda; 
       	do inicializar_csv_qgis;
       	
        // Create main agents
        create Bairro from: BA_setores_CD20220_shape_file;
        create AnalyserAgent;
        create PredictorAgent;
        create CommunicationAgent;
        
        // Create Consumptino of Residences
        create ConsumoResidencia from: arquivo_consumo {
            sk_matricula <- string(self["SK_MATRICULA"]);
            am_referencia <- int(self["AM_REFERENCIA"]);
            nn_consumo <- float(self["HCLQTCON"]);
        }
        
        write "Indexando dados de consumo de 12m...";
        map<string, list<ConsumoResidencia>> consumos_agrupados <- ConsumoResidencia group_by each.sk_matricula;
        
        loop matricula over: consumos_agrupados.keys {
            list<ConsumoResidencia> lista <- consumos_agrupados[matricula];
            if (!empty(lista)) {
                 map_consumo_real_12m[matricula] <- lista mean_of each.nn_consumo;
            }
        }
        write "Indexação concluída. " + length(map_consumo_real_12m) + " matrículas com consumo real encontradas.";
       
        
        create Residencia from: arquivo {
            sk_matricula <- string(self["SK_MATRICULA"]);
            nm_subcategoria <- self["NM_SUBCATEGORIA"];
            cd_setor <- self["CD_SETOR"];
            nn_media_consumo <- float(self["NN_MEDIA_CONSUMO"]);
            nn_consumo_diario <- float(self["NN_CONSUMO_DIARIO"]);
            tp_comportamento <- self["TP_COMPORTAMENTO"];
            nn_moradores_inicial <- int(self["NN_MORADORES_ANALISE"]);
            st_piscina <- int(self["ST_PISCINA"]);
            
            // Initializes the base income (vl_renda) for all scenarios.
            float renda_inicial <- float(self["VL_RENDA_MEDIA_RESPONSAVEL"]);
            
            // Income Fallback Logic: If it comes back as 0 or empty, it is possible sets a pattern.
            if (renda_inicial <= 0.0) {
                //renda_inicial <- 1518.0; // Remove this comment if you want to set a default income for those with 0.0
                //write "Aviso: Matrícula " + sk_matricula + " com renda mínima padrão.";
                residencias_com_renda_padarao <- residencias_com_renda_padarao + 1;
            }
            
            nn_moradores<- nn_moradores_inicial;
            // Initialization of all isolated income variables.
            vl_renda_cI <- renda_inicial;
            vl_renda_cII <- renda_inicial;
            vl_renda_cIII <- renda_inicial;
            vl_renda_cIV <- renda_inicial;
            vl_renda_cV <- renda_inicial;
            vl_renda_cVI <- renda_inicial;
            vl_renda_cVII <- renda_inicial;
            vl_renda_cVIII <- renda_inicial;
            vl_renda_cIX <- renda_inicial;
            vl_renda_cX <- renda_inicial;
            vl_renda_cXI <- renda_inicial;
            vl_renda_cXII <- renda_inicial;
            vl_renda_cXIII <- renda_inicial;
            vl_renda_cXIV <- renda_inicial;
            vl_renda_cXV <- renda_inicial;
            
            // Initialization of all initial income variables (for linear calculation)
            vl_renda_inicial_cI <- renda_inicial;
            vl_renda_inicial_cII <- renda_inicial;
            vl_renda_inicial_cIII <- renda_inicial;
            vl_renda_inicial_cIV <- renda_inicial;
            vl_renda_inicial_cV <- renda_inicial;
            vl_renda_inicial_cVI <- renda_inicial;
            vl_renda_inicial_cVII <- renda_inicial;
            vl_renda_inicial_cVIII <- renda_inicial;
            vl_renda_inicial_cIX <- renda_inicial;
            vl_renda_inicial_cX <- renda_inicial;
            vl_renda_inicial_cXI <- renda_inicial;
            vl_renda_inicial_cXII <- renda_inicial;
            vl_renda_inicial_cXIII <- renda_inicial;
            vl_renda_inicial_cXIV <- renda_inicial;
            vl_renda_inicial_cXV <- renda_inicial;
            
            //Coordinate processing
            if !(self["X"] = "" or self["Y"] = "") {
                latitude <- float(self["X"]);
                longitude <- float(self["Y"]);
                geometry gama_location <- to_GAMA_CRS({latitude, longitude});
                location <- point(gama_location);
            } else {
                location <- {0.0, 0.0};
            }
            
            bool tem_consumo_real <- (sk_matricula in map_consumo_real_12m.keys);
            float consumo_inicial <- 0.0;

            if (tem_consumo_real) {
                consumo_inicial <- map_consumo_real_12m[sk_matricula];
            } else {
                residencias_sem_consumo <- residencias_sem_consumo + 1;
                matriculas_sem_consumo << sk_matricula;
                
                if (tp_comportamento = 'AMBIENTALISTA') {
                    consumo_inicial <- (media_ambientalista * nn_moradores * 30.5) / 1000;
                } else if (tp_comportamento = 'PERDULARIO') {
                    consumo_inicial <- (media_perdulario * nn_moradores * 30.5) / 1000;
                } else {
                    consumo_inicial <- (media_moderado * nn_moradores * 30.5) / 1000;
                }
            }
            consumo_atual_cI <- consumo_inicial;
            consumo_atual_cII <- consumo_inicial;
            consumo_atual_cIII <- consumo_inicial;
            consumo_atual_cIV <- consumo_inicial;
            consumo_atual_cV <- consumo_inicial;
            consumo_atual_cVI <- consumo_inicial;
            consumo_atual_cVII <- consumo_inicial;
            consumo_atual_cVIII <- consumo_inicial;
            consumo_atual_cIX <- consumo_inicial;
            consumo_atual_cX <- consumo_inicial;
            consumo_atual_cXI <- consumo_inicial;
            consumo_atual_cXII <- consumo_inicial;
            consumo_atual_cXIII <- consumo_inicial;
            consumo_atual_cXIV <- consumo_inicial;
            consumo_atual_cXV <- consumo_inicial;
        }
    }
    
    reflex contar_residencias {
        total_residencias <- 0;
        total_ambientalistas <- 0;
        total_perdularios <- 0;
        total_moderados <- 0;

        ask Residencia {
            total_residencias <- total_residencias + 1;

            if (tp_comportamento = 'AMBIENTALISTA') {
                total_ambientalistas <- total_ambientalistas + 1;
            } else if (tp_comportamento = 'PERDULARIO') {
                total_perdularios <- total_perdularios + 1;
            } else {
                total_moderados <- total_moderados + 1;
            }
        }

        historico_total_residencias << total_residencias;
        historico_ambientalistas << total_ambientalistas;
        historico_perdularios << total_perdularios;
        historico_moderados << total_moderados;
    }
    

	// REFLEX: Applies annual shares (Income) only in Month 1
    reflex atualizar_anualmente when: mes_corrente = 1 and ano_corrente > 2025 {
        write "--- Iniciando ajustes anuais de RENDA para o ano " + string(ano_corrente) + " ---";
        
        ask Residencia {
            // Linear Income Scenarios (C IV, C VII, C X, C XIII)
            do atualizar_renda_linear_cIV;
            do atualizar_renda_linear_cVII;
            do atualizar_renda_linear_cX;
            do atualizar_renda_linear_cXIII;
            
            // Equilibrium Income Scenarios (C V, C VIII, C XI, C XIV)
            do atualizar_renda_equilibrio_cV;
            do atualizar_renda_equilibrio_cVIII;
            do atualizar_renda_equilibrio_cXI;
            do atualizar_renda_equilibrio_cXIV;

            // Income Scenarios IMBALANCE (C VI, C IX, C XII, C XV)
            do atualizar_renda_desequilibrio_cVI;
            do atualizar_renda_desequilibrio_cIX;
            do atualizar_renda_desequilibrio_cXII;
            do atualizar_renda_desequilibrio_cXV;
            
            // Randomness Scenarios in Income (C XVI, C XVII, C XVIII)
            do atualizar_renda_aleatoria_linear_cXVI;
        	do atualizar_renda_aleatoria_equilibrio_cXVII;
        	do atualizar_renda_aleatoria_desequilibrio_cXVIII;
        }
    }
    //Reflex to calculate the monthly consumption of each residence by scenario.
    reflex calcular_consumo_mensal {    
        // Update consumption forecasts
        ask Residencia {
            do prever_consumo_todos_cenarios;
            if(cycle = 119){
            	do exportar_resultados_qgis;
            	
            }
        }
        
        string mes_ano <- string(mes_corrente) + "/" + string(ano_corrente);
        
        float cI_total <- Residencia sum_of each.consumo_atual_cI;
        float cII_total <- Residencia sum_of each.consumo_atual_cII;
        float cIII_total <- Residencia sum_of each.consumo_atual_cIII;
        float cIV_total <- Residencia sum_of each.consumo_atual_cIV;
        float cV_total <- Residencia sum_of each.consumo_atual_cV;
        float cVI_total <- Residencia sum_of each.consumo_atual_cVI;
        float cVII_total <- Residencia sum_of each.consumo_atual_cVII;
        float cVIII_total <- Residencia sum_of each.consumo_atual_cVIII;
        float cIX_total <- Residencia sum_of each.consumo_atual_cIX;
        float cX_total <- Residencia sum_of each.consumo_atual_cX;
        float cXI_total <- Residencia sum_of each.consumo_atual_cXI;
        float cXII_total <- Residencia sum_of each.consumo_atual_cXII;
        float cXIII_total <- Residencia sum_of each.consumo_atual_cXIII;
        float cXIV_total <- Residencia sum_of each.consumo_atual_cXIV;
        float cXV_total <- Residencia sum_of each.consumo_atual_cXV;
        float cXVI_total <- Residencia sum_of each.consumo_atual_cXVI;
    	float cXVII_total <- Residencia sum_of each.consumo_atual_cXVII;
    	float cXVIII_total <- Residencia sum_of each.consumo_atual_cXVIII;
    

        consumo_anual_total_cI << cI_total;
        consumo_anual_total_cII << cII_total;
        consumo_anual_total_cIII << cIII_total;
        consumo_anual_total_cIV << cIV_total;
        consumo_anual_total_cV << cV_total;
        consumo_anual_total_cVI << cVI_total;
        consumo_anual_total_cVII << cVII_total;
        consumo_anual_total_cVIII << cVIII_total;
        consumo_anual_total_cIX << cIX_total;
        consumo_anual_total_cX << cX_total;
        consumo_anual_total_cXI << cXI_total;
        consumo_anual_total_cXII << cXII_total;
        consumo_anual_total_cXIII << cXIII_total;
        consumo_anual_total_cXIV << cXIV_total;
        consumo_anual_total_cXV << cXV_total;
    	consumo_anual_total_cXVI << cXVI_total;
    	consumo_anual_total_cXVII << cXVII_total;
    	consumo_anual_total_cXVIII << cXVIII_total;
    
    map<string, float> consumo_mensal_dados <- map([
        "Ano"::float(ano_corrente),
        "Mes"::float(mes_corrente),
        "Consumo_CI"::cI_total,
        "Consumo_CII"::cII_total,
        "Consumo_CIII"::cIII_total,
        "Consumo_CIV"::cIV_total,
        "Consumo_CV"::cV_total,
        "Consumo_CVI"::cVI_total,
        "Consumo_CVII"::cVII_total,
        "Consumo_CVIII"::cVIII_total,
        "Consumo_CIX"::cIX_total,
        "Consumo_CX"::cX_total,
        "Consumo_CXI"::cXI_total,
        "Consumo_CXII"::cXII_total,
        "Consumo_CXIII"::cXIII_total,
        "Consumo_CXIV"::cXIV_total,
        "Consumo_CXV"::cXV_total,
        "Consumo_CXVI"::cXVI_total,
        "Consumo_CXVII"::cXVII_total,
        "Consumo_CXVIII"::cXVIII_total
    ]);
            
    write "Consumo total CIV (" + mes_ano + "): " + cIV_total;


        // Weather update
        mes_corrente <- mes_corrente + 1;
        if (mes_corrente > 12) {
            mes_corrente <- 1;
            ano_corrente <- ano_corrente + 1;
        }
    }
    
    reflex stop_simulation when: ano_corrente = 2035 {
    	do gerar_csv_consumo;
        do pause;
    }

	reflex coordenar_agentes {
        // Main execution flow of the agents
        ask AnalyserAgent {
            do coletar_dados;
            do processar_dados;
        }
        
        // Passing processed data to Predictor Agent
        list<float> dados_para_predictor <- dados_processados;
        ask PredictorAgent {
            dados_recebidos <- dados_para_predictor;
            do calcular_previsao;
        }
        
        // Passing consumption_predictions to CommunicationAgent
        list<float> dados_para_comm <- previsoes_consumo;
        ask CommunicationAgent {
            dados_relatorio <- dados_para_comm;
            do gerar_relatorio;
        }
    }
    
    // Function to generate a CSV file with all scenarios.
	action gerar_csv_consumo {
    string caminho_csv <- "../resultados/consumo_previsto_todos_cenarios.csv";
    
    // Create a CSV header with all scenarios.
    string conteudo_csv <- "Mes;Ano;Mes_Ano;";
    conteudo_csv <- conteudo_csv + "CI_Pop_Uniforme;";
    conteudo_csv <- conteudo_csv + "CII_Ambientalistas;";
    conteudo_csv <- conteudo_csv + "CIII_Perdularios;";
    conteudo_csv <- conteudo_csv + "CIV_PopUnif_RendaLinear;";
    conteudo_csv <- conteudo_csv + "CV_PopUnif_RendaEquilibrio;";
    conteudo_csv <- conteudo_csv + "CVI_PopUnif_RendaDesequilibrio;";
    conteudo_csv <- conteudo_csv + "CVII_PopAleat_RendaLinear;";
    conteudo_csv <- conteudo_csv + "CVIII_PopAleat_RendaEquilibrio;";
    conteudo_csv <- conteudo_csv + "CIX_PopAleat_RendaDesequilibrio;";
    conteudo_csv <- conteudo_csv + "CX_Ambient_RendaLinear;";
    conteudo_csv <- conteudo_csv + "CXI_Ambient_RendaEquilibrio;";
    conteudo_csv <- conteudo_csv + "CXII_Ambient_RendaDesequilibrio;";
    conteudo_csv <- conteudo_csv + "CXIII_Perdul_RendaLinear;";
    conteudo_csv <- conteudo_csv + "CXIV_Perdul_RendaEquilibrio;";
    conteudo_csv <- conteudo_csv + "CXV_Perdul_RendaDesequilibrio";
    conteudo_csv <- conteudo_csv + ";CXVI_PopUnif_RendaAleatLinear";
    conteudo_csv <- conteudo_csv + ";CXVII_PopUnif_RendaAleatEquilibrio";
    conteudo_csv <- conteudo_csv + ";CXVIII_PopUnif_RendaAleatDesequilibrio";
    
    conteudo_csv <- conteudo_csv + "\n";
    
    // Check if all lists are the same size.
    int num_meses <- length(consumo_anual_total_cI);
    
    // Add data month by month.
    loop i from: 0 to: num_meses - 1 {
        // Calculate the corresponding month and year.
        int mes <- (i mod 12) + 1;
        int ano <- 2025 + int(i / 12);
        string mes_ano <- string(mes) + "/" + string(ano);
        
        // Obter valores de cada cenário (usar 0 se a lista for menor)
        float ci_val <- (i < length(consumo_anual_total_cI)) ? consumo_anual_total_cI[i] : 0.0;
        float cii_val <- (i < length(consumo_anual_total_cII)) ? consumo_anual_total_cII[i] : 0.0;
        float ciii_val <- (i < length(consumo_anual_total_cIII)) ? consumo_anual_total_cIII[i] : 0.0;
        float civ_val <- (i < length(consumo_anual_total_cIV)) ? consumo_anual_total_cIV[i] : 0.0;
        float cv_val <- (i < length(consumo_anual_total_cV)) ? consumo_anual_total_cV[i] : 0.0;
        float cvi_val <- (i < length(consumo_anual_total_cVI)) ? consumo_anual_total_cVI[i] : 0.0;
        float cvii_val <- (i < length(consumo_anual_total_cVII)) ? consumo_anual_total_cVII[i] : 0.0;
        float cviii_val <- (i < length(consumo_anual_total_cVIII)) ? consumo_anual_total_cVIII[i] : 0.0;
        float cix_val <- (i < length(consumo_anual_total_cIX)) ? consumo_anual_total_cIX[i] : 0.0;
        float cx_val <- (i < length(consumo_anual_total_cX)) ? consumo_anual_total_cX[i] : 0.0;
        float cxi_val <- (i < length(consumo_anual_total_cXI)) ? consumo_anual_total_cXI[i] : 0.0;
        float cxii_val <- (i < length(consumo_anual_total_cXII)) ? consumo_anual_total_cXII[i] : 0.0;
        float cxiii_val <- (i < length(consumo_anual_total_cXIII)) ? consumo_anual_total_cXIII[i] : 0.0;
        float cxiv_val <- (i < length(consumo_anual_total_cXIV)) ? consumo_anual_total_cXIV[i] : 0.0;
        float cxv_val <- (i < length(consumo_anual_total_cXV)) ? consumo_anual_total_cXV[i] : 0.0;
        float cxvi_val <- (i < length(consumo_anual_total_cXVI)) ? consumo_anual_total_cXVI[i] : 0.0;
        float cxvii_val <- (i < length(consumo_anual_total_cXVII)) ? consumo_anual_total_cXVII[i] : 0.0;
        float cxviii_val <- (i < length(consumo_anual_total_cXVIII)) ? consumo_anual_total_cXVIII[i] : 0.0;
        
        // Add line to CSV
        conteudo_csv <- conteudo_csv + 
            string(mes) + ";" +
            string(ano) + ";" +
            mes_ano + ";" +
            replace(string(ci_val),".",",") + ";" +
            replace(string(cii_val),".",",") + ";" +
            replace(string(ciii_val),".",",") + ";" +
            replace(string(civ_val),".",",") + ";" +
            replace(string(cv_val),".",",") + ";" +
            replace(string(cvi_val),".",",") + ";" +
            replace(string(cvii_val),".",",") + ";" +
            replace(string(cviii_val),".",",") + ";" +
            replace(string(cix_val),".",",") + ";" +
            replace(string(cx_val),".",",") + ";" +
            replace(string(cxi_val),".",",") + ";" +
            replace(string(cxii_val),".",",") + ";" +
            replace(string(cxiii_val),".",",") + ";" +
            replace(string(cxiv_val),".",",") + ";" +
            replace(string(cxv_val),".",",") + ";" +
            replace(string(cxvi_val),".",",") + ";" +
            replace(string(cxvii_val),".",",") + ";" +
            replace(string(cxviii_val),".",",") + "\n";
    }
    
    // Save file
    save conteudo_csv type: "text" to: caminho_csv;
    
    write "Arquivo CSV gerado com todos os cenários: " + caminho_csv;
    write "Total de meses registrados: " + num_meses;
}
}

species AnalyserAgent {
    list<float> dados_coletados;
    
    action coletar_dados {
        dados_coletados <- Residencia collect each.consumo_atual_cI;
        write "AnalyserAgent: Dados coletados de " + length(dados_coletados) + " residências";
    }
    
    action processar_dados {
        float media <- mean(dados_coletados);
        float desvio <- standard_deviation(dados_coletados);
        
        dados_processados <- dados_coletados where (each < (media + 3 * desvio) and each > (media - 3 * desvio));
        
        write "AnalyserAgent: Dados processados (média: " + media + ", desvio: " + desvio + ")";
    }
}

species PredictorAgent {
    list<float> dados_recebidos;
    list<float> previsoes;
    
    action calcular_previsao {
    if (!empty(dados_recebidos)) {
        int tamanho_lista <- length(dados_recebidos);
        
        float ultimo_valor <- dados_recebidos[tamanho_lista - 1];
        
        int indice_ano <- ano_corrente - 2025;
        
        if (indice_ano >= 0 and indice_ano < length(taxas_crescimento_mensal)) {
            float taxa <- taxas_crescimento_mensal[indice_ano];
            float previsao <- ultimo_valor * (1 + taxa);
            
            previsoes << previsao;
            previsoes_consumo <- previsoes;
            
            write "PredictorAgent: Previsão calculada para " + 
                  mes_corrente + "/" + ano_corrente + 
                  ": " + previsao + 
                  " (taxa: " + taxa + ", último valor: " + ultimo_valor + ")";
        } else {
            write "PredictorAgent: Índice de ano fora dos limites: " + indice_ano;
        }
    } else {
        write "PredictorAgent: Nenhum dado recebido para processamento";
    }
}
}

species CommunicationAgent {
    list<float> dados_relatorio;
    
    action gerar_relatorio {
        if (!empty(dados_relatorio)) {
            float consumo_total <- sum(dados_relatorio);
            relatorio_final << consumo_total;
            
            float media <- mean(dados_relatorio);
            float maximo <- max(dados_relatorio);
            float minimo <- min(dados_relatorio);
            
            write "CommunicationAgent: Relatório gerado - Consumo total: " + consumo_total;
            write "Estatísticas - Média: " + media + ", Máximo: " + maximo + ", Mínimo: " + minimo;
        } else {
            write "CommunicationAgent: Nenhum dado recebido para relatório";
        }
    }
}

species ConsumoResidencia {
    string sk_matricula;
    int am_referencia;
    float nn_consumo;
}

species Residencia {
    // Species identification variables for households
    string sk_matricula;
    string cd_setor;
    float nn_media_consumo;
    float nn_consumo_diario;
    string nm_subcategoria;
    string tp_comportamento;
    float latitude;  
    float longitude;
    
    //Global state variables (population/house characteristics)
    float nn_moradores;
    float nn_moradores_inicial;
    int st_piscina;
    
    // --- DECLARATION OF THE 18 CONSUMPTION VARIABLES ---

	// They need to be here so that each agent can store its individual value
    float consumo_mensal_cI; float consumo_mensal_cII; float consumo_mensal_cIII;
    float consumo_mensal_cIV; float consumo_mensal_cV; float consumo_mensal_cVI;
    float consumo_mensal_cVII; float consumo_mensal_cVIII; float consumo_mensal_cIX;
    float consumo_mensal_cX; float consumo_mensal_cXI; float consumo_mensal_cXII;
    float consumo_mensal_cXIII; float consumo_mensal_cXIV; float consumo_mensal_cXV;
    float consumo_mensal_cXVI; float consumo_mensal_cXVII; float consumo_mensal_cXVIII;
    
    // Variables for calculating the new profile (required for export)
    string tp_novo_comportamento;
    float nn_nova_media_consumo;
    float nn_novo_consumo_diario;
    
    // Income variables
    float vl_renda_cI; float vl_renda_inicial_cI;
    float vl_renda_cII; float vl_renda_inicial_cII;
    float vl_renda_cIII; float vl_renda_inicial_cIII;
    float vl_renda_cIV; float vl_renda_inicial_cIV;
    float vl_renda_cV; float vl_renda_inicial_cV;
    float vl_renda_cVI; float vl_renda_inicial_cVI;
    float vl_renda_cVII; float vl_renda_inicial_cVII;
    float vl_renda_cVIII; float vl_renda_inicial_cVIII;
    float vl_renda_cIX; float vl_renda_inicial_cIX;
    float vl_renda_cX; float vl_renda_inicial_cX;
    float vl_renda_cXI; float vl_renda_inicial_cXI;
    float vl_renda_cXII; float vl_renda_inicial_cXII;
    float vl_renda_cXIII; float vl_renda_inicial_cXIII;
    float vl_renda_cXIV; float vl_renda_inicial_cXIV;
    float vl_renda_cXV; float vl_renda_inicial_cXV;
	float vl_renda_cXVI; float vl_renda_inicial_cXVI;
    float vl_renda_cXVII; float vl_renda_inicial_cXVII;
    float vl_renda_cXVIII; float vl_renda_inicial_cXVIII;
    
   //Consumption variables
    float consumo_atual_cI;  
    float consumo_atual_cII; 
    float consumo_atual_cIII;
    float consumo_atual_cIV;
    float consumo_atual_cV;
    float consumo_atual_cVI;
    float consumo_atual_cVII;
    float consumo_atual_cVIII;
    float consumo_atual_cIX;
    float consumo_atual_cX;
    float consumo_atual_cXI;
    float consumo_atual_cXII;
    float consumo_atual_cXIII;
    float consumo_atual_cXIV;
    float consumo_atual_cXV;
    float consumo_atual_cXVI;
    float consumo_atual_cXVII;
    float consumo_atual_cXVIII;
    
    // Variable to control whether the residence has random growth.
    bool tem_crescimento_aleatorio <- flip(probabilidade_crescimento_aleatorio);
    
    float get_taxa_crescimento_mensal {
        int indice_ano <- ano_corrente - 2025;
        if (indice_ano >= 0 and indice_ano < length(taxas_crescimento_mensal)) {
            return taxas_crescimento_mensal[indice_ano];
        }
        return 0.0;
    }
    
    float get_percentual_aumento_renda {
        int indice_ano <- ano_corrente - 2025;
        if (indice_ano >= 0 and indice_ano < length(percentuais_aumento_renda)) {
            return percentuais_aumento_renda[indice_ano];
        }
        return 0.0;
    }
    
    
// --- ACTION FOR EXPORTING RESULTS BY HOUSEHOLD  ---
    action exportar_cenario(string nome_cen, float valor_final, float valor_nn_moradores) {
        nn_nova_media_consumo <- valor_final;
        nn_novo_consumo_diario <- (nn_nova_media_consumo * 1000 / valor_nn_moradores ) / 30.5;

        // Reclassification based on ranges
        if (nn_novo_consumo_diario < 100.0) {
            tp_novo_comportamento <- "AMBIENTALISTA";
        } else if (nn_novo_consumo_diario <= 121.5) {
            tp_novo_comportamento <- "MODERADO";
        } else {
            tp_novo_comportamento <- "PERDULARIO";
        }

        // Save line on CSV
        save [sk_matricula, cd_setor, tp_comportamento, nn_media_consumo, nn_consumo_diario, nn_moradores_inicial,
              nome_cen, tp_novo_comportamento, nn_nova_media_consumo, nn_novo_consumo_diario, valor_nn_moradores] 
        to: "../resultados/comparativo_perfil_cenarios_qgis.csv" type: "csv" rewrite: false;
    }

    // --- FINAL REFLECTION (Cycle 119) FOR EXPORTING SCENARIOS ---
    action exportar_resultados_qgis {
        do exportar_cenario("CI", consumo_atual_cI, nn_moradores);
        do exportar_cenario("CII", consumo_atual_cII, nn_moradores);
        do exportar_cenario("CIII", consumo_atual_cIII, nn_moradores);
        do exportar_cenario("CIV", consumo_atual_cIV, nn_moradores);
        do exportar_cenario("CV", consumo_atual_cV, nn_moradores);
        do exportar_cenario("CVI", consumo_atual_cVI, nn_moradores);
        do exportar_cenario("CVII", consumo_atual_cVII, nn_moradores);
        do exportar_cenario("CVIII", consumo_atual_cVIII, nn_moradores);
        do exportar_cenario("CIX", consumo_atual_cIX, nn_moradores);
        do exportar_cenario("CX", consumo_atual_cX, nn_moradores);
        do exportar_cenario("CXI", consumo_atual_cXI, nn_moradores);
        do exportar_cenario("CXII", consumo_atual_cXII, nn_moradores);
        do exportar_cenario("CXIII", consumo_atual_cXIII, nn_moradores);
        do exportar_cenario("CXIV", consumo_atual_cXIV, nn_moradores);
        do exportar_cenario("CXV", consumo_atual_cXV, nn_moradores);
        do exportar_cenario("CXVI", consumo_atual_cXVI, nn_moradores);
        do exportar_cenario("CXVII", consumo_atual_cXVII, nn_moradores);
        do exportar_cenario("CXVIII", consumo_atual_cXVIII, nn_moradores);
    }    
// RESIDENT UPDATE ACTION (UNIFORM - MONTHLY)
    action atualizar_moradores {
        float taxa_mensal <- get_taxa_crescimento_mensal();
        nn_moradores <- int(nn_moradores * (1 + taxa_mensal));
    }
// ACTIONS FOR SCENARIOS VII-IX: Random Population Growth
    
	// Resident update with random selection
    action atualizar_moradores_aleatorio {
        if (tem_crescimento_aleatorio) {
            float taxa_mensal <- get_taxa_crescimento_mensal();
            nn_moradores <- int(nn_moradores * (1 + taxa_mensal));
        }
    }
    
    
    // **************** INCOME UPDATE ACTIONS (ANNUAL) ****************
    
    // --- Linear income (fixed increase) ---
    action atualizar_renda_linear_cIV {
        float percentual <- get_percentual_aumento_renda();
        vl_renda_cIV <- vl_renda_cIV + (vl_renda_cIV * percentual);
    }
    action atualizar_renda_linear_cVII {
        float percentual <- get_percentual_aumento_renda();
        vl_renda_cVII <- vl_renda_cVII + (vl_renda_cVII * percentual);
    }
    action atualizar_renda_linear_cX {
        float percentual <- get_percentual_aumento_renda();
        // Only environmentalists have their income updated in this scenario (if growth is linear).
        if (tp_comportamento = 'AMBIENTALISTA') { 
            vl_renda_cX <- vl_renda_cX + (vl_renda_cX * percentual);
        }
    }
    action atualizar_renda_linear_cXIII {
        float percentual <- get_percentual_aumento_renda();
        // Only wastefull have their income updated in this scenario (if growth is linear).
        if (tp_comportamento = 'PERDULARIO') {
            vl_renda_cXIII <- vl_renda_cXIII + (vl_renda_cXIII * percentual);
        }
    }

    // --- Balanced Income ---
    action atualizar_renda_equilibrio_cV {
	    float percentual <- get_percentual_aumento_renda();
        float fator_desigualdade <- 1.0;
        if (vl_renda_cV < limite_baixa_renda) { fator_desigualdade <- 1.1; } 
        else if (vl_renda_cV > limite_alta_renda) { fator_desigualdade <- 1.05; }
	    vl_renda_cV <- vl_renda_cV * (1 + percentual * fator_desigualdade);
    }
    action atualizar_renda_equilibrio_cVIII {
	    float percentual <- get_percentual_aumento_renda();
        float fator_desigualdade <- 1.0;
        if (vl_renda_cVIII < limite_baixa_renda) { fator_desigualdade <- 1.1; } 
        else if (vl_renda_cVIII > limite_alta_renda) { fator_desigualdade <- 1.05; }
	    vl_renda_cVIII <- vl_renda_cVIII * (1 + percentual * fator_desigualdade);
    }
    action atualizar_renda_equilibrio_cXI {
	    if (tp_comportamento = 'AMBIENTALISTA') {
            float percentual <- get_percentual_aumento_renda();
            float fator_desigualdade <- 1.0;
            if (vl_renda_cXI < limite_baixa_renda) { fator_desigualdade <- 1.1; } 
            else if (vl_renda_cXI > limite_alta_renda) { fator_desigualdade <- 1.05; }
            vl_renda_cXI <- vl_renda_cXI * (1 + percentual * fator_desigualdade);
        }
    }
    action atualizar_renda_equilibrio_cXIV {
	    if (tp_comportamento = 'PERDULARIO') {
            float percentual <- get_percentual_aumento_renda();
            float fator_desigualdade <- 1.0;
            if (vl_renda_cXIV < limite_baixa_renda) { fator_desigualdade <- 1.1; } 
            else if (vl_renda_cXIV > limite_alta_renda) { fator_desigualdade <- 1.05; }
            vl_renda_cXIV <- vl_renda_cXIV * (1 + percentual * fator_desigualdade);
        }
    }

    // --- Income IMBALANCE ---
    action atualizar_renda_desequilibrio_cVI {
	    float percentual <- get_percentual_aumento_renda();
        float fator_desigualdade <- 1.0;
        if (vl_renda_cVI < limite_baixa_renda) { fator_desigualdade <- 1.05; } 
        else if (vl_renda_cVI > limite_alta_renda) { fator_desigualdade <- 1.1; }
	    vl_renda_cVI <- vl_renda_cVI * (1 + percentual * fator_desigualdade);
    }
    action atualizar_renda_desequilibrio_cIX {
	    float percentual <- get_percentual_aumento_renda();
        float fator_desigualdade <- 1.0;
        if (vl_renda_cIX < limite_baixa_renda) { fator_desigualdade <- 1.05; } 
        else if (vl_renda_cIX > limite_alta_renda) { fator_desigualdade <- 1.1; }
	    vl_renda_cIX <- vl_renda_cIX * (1 + percentual * fator_desigualdade);
    }
    action atualizar_renda_desequilibrio_cXII {
	    if (tp_comportamento = 'AMBIENTALISTA') {
            float percentual <- get_percentual_aumento_renda();
            float fator_desigualdade <- 1.0;
            if (vl_renda_cXII < limite_baixa_renda) { fator_desigualdade <- 1.05; } 
            else if (vl_renda_cXII > limite_alta_renda) { fator_desigualdade <- 1.1; }
            vl_renda_cXII <- vl_renda_cXII * (1 + percentual * fator_desigualdade);
        }
    }
    action atualizar_renda_desequilibrio_cXV {
	    if (tp_comportamento = 'PERDULARIO') {
            float percentual <- get_percentual_aumento_renda();
            float fator_desigualdade <- 1.0;
            if (vl_renda_cXV < limite_baixa_renda) { fator_desigualdade <- 1.05; } 
            else if (vl_renda_cXV > limite_alta_renda) { fator_desigualdade <- 1.1; }
            vl_renda_cXV <- vl_renda_cXV * (1 + percentual * fator_desigualdade);
        }
    }

    // ACTIONS FOR SCENARIOS XVI-XVIII: Randomness in Income
    
    // Linear Income with Randomness
    action atualizar_renda_aleatoria_linear_cXVI {
        float percentual <- get_percentual_aumento_renda();
        // Adds randomness: +/- 30% of the percentage
        float variacao <- rnd(-0.3, 0.3);
        float percentual_ajustado <- percentual * (1 + variacao);
        vl_renda_cXVI <- vl_renda_cXVI * (1 + percentual_ajustado);
    }
    
    // Balanced Income with Randomness
    action atualizar_renda_aleatoria_equilibrio_cXVII {
        float percentual <- get_percentual_aumento_renda();
        float fator_desigualdade <- 1.0;
        
        if (vl_renda_cXVII < limite_baixa_renda) { 
            fator_desigualdade <- 1.1; 
        } else if (vl_renda_cXVII > limite_alta_renda) { 
            fator_desigualdade <- 1.05; 
        }
        
        // Randomness: +5% to +10% increase in the factor
        float variacao <- rnd(0.05, 0.1);
        fator_desigualdade <- fator_desigualdade * (1 + variacao);
        
        vl_renda_cXVII <- vl_renda_cXVII * (1 + percentual * fator_desigualdade);
    }
    
    // Income Imbalance with Randomness
    action atualizar_renda_aleatoria_desequilibrio_cXVIII {
        float percentual <- get_percentual_aumento_renda();
        float fator_desigualdade <- 1.0;
        
        if (vl_renda_cXVIII < limite_baixa_renda) { 
            fator_desigualdade <- 1.05; 
        } else if (vl_renda_cXVIII > limite_alta_renda) { 
            fator_desigualdade <- 1.1; 
        }
        
        // Randomness: +/- 25% in the factor
        float variacao <- rnd(0.05, 0.1);
        fator_desigualdade <- fator_desigualdade * (1 + variacao);
        
        vl_renda_cXVIII <- vl_renda_cXVIII * (1 + percentual * fator_desigualdade);
    }
    
	// MONTHLY CONSUMPTION FORECASTING ACTION
    action prever_consumo_todos_cenarios {
        float taxa_mensal <- get_taxa_crescimento_mensal();
        // It only updates the number of residents (uniform).
        do atualizar_moradores; 
        
        // Uniform population growth factor (applied to all)
        float fator_pop <- (1 + taxa_mensal); 

        // Scenario 1: Uniform growth, without income factor.
        consumo_atual_cI <- consumo_atual_cI * fator_pop;

        // Scenario II: Environmentalists, without income factor.
        if (tp_comportamento = 'AMBIENTALISTA') {
            consumo_atual_cII <- consumo_atual_cII * fator_pop;
        } else {
            consumo_atual_cII <- consumo_atual_cII; // It won't grow if it's not environmentally friendly.
        }

        // Scenario III: Wastefull, without an income factor.
        if (tp_comportamento = 'PERDULARIO') {
            consumo_atual_cIII <- consumo_atual_cIII * fator_pop;
        } else {
            consumo_atual_cIII <- consumo_atual_cIII; // It doesn't grow if it's not wasteful.
        }
                
        // Scenario IV: Uniform Population vs. Linear Income
        float fator_renda_cIV <- (1.0 + (vl_renda_cIV * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cIV * sensibilidade_renda));
        consumo_atual_cIV <- consumo_atual_cI * fator_renda_cIV;
        
        // Scenario V: Uniform Population vs. Equilibrium Income
        float fator_renda_cV <- (1.0 + (vl_renda_cV * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cV * sensibilidade_renda));
        consumo_atual_cV <- consumo_atual_cI * fator_renda_cV;
        
        // Scenario VI: Uniform Population vs. Income Imbalance
        float fator_renda_cVI <- (1.0 + (vl_renda_cVI * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cVI * sensibilidade_renda));
        consumo_atual_cVI <- consumo_atual_cI * fator_renda_cVI;
        
        // --- Scenarios VII to IX (Random Pop) ---
        float base_aleatoria <- consumo_atual_cI;
        if (!tem_crescimento_aleatorio) {
             base_aleatoria <- consumo_atual_cI / fator_pop; // Reverte o crescimento se não tiver
        }
        
        // Scenario VII: Random Population + Linear Income
        float fator_renda_cVII <- (1.0 + (vl_renda_cVII * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cVII * sensibilidade_renda));
        consumo_atual_cVII <- base_aleatoria * fator_renda_cVII;
        
        // Scenario VIII: Random Population + Equilibrium Income
        float fator_renda_cVIII <- (1.0 + (vl_renda_cVIII * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cVIII * sensibilidade_renda));
        consumo_atual_cVIII <- base_aleatoria * fator_renda_cVIII;
        
        // Scenario IX: Random Population + Income Imbalance
        float fator_renda_cIX <- (1.0 + (vl_renda_cIX * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cIX * sensibilidade_renda));
        consumo_atual_cIX <- base_aleatoria * fator_renda_cIX;
        
        
        if (tp_comportamento = 'AMBIENTALISTA') {
            // Scenario X: Environmentalist Population vs. Linear Income
            float fator_renda_cX <- (1.0 + (vl_renda_cX * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cX * sensibilidade_renda));
            consumo_atual_cX <- consumo_atual_cII * fator_renda_cX;
            
            // Scenario XI: Environmentalist Population vs. Equilibrium Income
            float fator_renda_cXI <- (1.0 + (vl_renda_cXI * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXI * sensibilidade_renda));
            consumo_atual_cXI <- consumo_atual_cII * fator_renda_cXI;
            
            // Scenario XII: Environmentalist Population vs. Income Imbalance
            float fator_renda_cXII <- (1.0 + (vl_renda_cXII * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXII * sensibilidade_renda));
            consumo_atual_cXII <- consumo_atual_cII * fator_renda_cXII;
        } else {
            // Scenario X: Environmentalist Population vs. Linear Income
            consumo_atual_cX <- consumo_atual_cII;
            
            // Scenario XI: Environmentalist Population vs. Equilibrium Income
            consumo_atual_cXI <- consumo_atual_cII;
            
            // Scenario XII: Environmentalist Population vs. Income Imbalance
            consumo_atual_cXII <- consumo_atual_cII;
        }
        
        if (tp_comportamento = 'PERDULARIO') {
            // Scenario XIII: Wasteful Population x Linear Income
            float fator_renda_cXIII <- (1.0 + (vl_renda_cXIII * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXIII * sensibilidade_renda));
            consumo_atual_cXIII <- consumo_atual_cIII * fator_renda_cXIII;
            
            // Scenario XIV: Wasteful Population x Income Equilibrium
            float fator_renda_cXIV <- (1.0 + (vl_renda_cXIV * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXIV * sensibilidade_renda));
            consumo_atual_cXIV <- consumo_atual_cIII * fator_renda_cXIV;
            
            // Scenario XV: Wasteful Population x Income Disequilibrium
            float fator_renda_cXV <- (1.0 + (vl_renda_cXV * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXV * sensibilidade_renda));
            consumo_atual_cXV <- consumo_atual_cIII * fator_renda_cXV;
        } else {
            // Scenario XIII: Wasteful Population x Linear Income
            consumo_atual_cXIII <- consumo_atual_cIII;
            
            // Scenario XIV: Wasteful Population vs. Equilibrium Income
            consumo_atual_cXIV <- consumo_atual_cIII;
            
            // Scenario XV: Wastfull Population  vs. Income Imbalance
            consumo_atual_cXV <- consumo_atual_cIII;
        }
        
        // Scenario XVI: Uniform Population + Linear Random Income
        float fator_renda_cXVI <- (1.0 + (vl_renda_cXVI * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXVI * sensibilidade_renda));
        // Randomness in consumption: +/- 15%
        float variacao_cXVI <- rnd(-0.15, 0.15);
        consumo_atual_cXVI <- consumo_atual_cI * fator_renda_cXVI * (1 + variacao_cXVI);
        
        // Scenario XVII: Uniform Population + Random Income Equilibrium
        float fator_renda_cXVII <- (1.0 + (vl_renda_cXVII * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXVII * sensibilidade_renda));
        float variacao_cXVII <- rnd(-0.15, 0.15);
        consumo_atual_cXVII <- consumo_atual_cI * fator_renda_cXVII * (1 + variacao_cXVII);
        
        // Scenario XVIII: Uniform Population + Random Income - Disequilibrium
        float fator_renda_cXVIII <- (1.0 + (vl_renda_cXVIII * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXVIII * sensibilidade_renda));
        float variacao_cXVIII <- rnd(-0.15, 0.15);
        consumo_atual_cXVIII <- consumo_atual_cI * fator_renda_cXVIII * (1 + variacao_cXVIII);
    
    }
    aspect base {
        if (latitude != 0.0 and longitude != 0.0) {
            if(tp_comportamento='AMBIENTALISTA') {
                draw circle(3) color: #green border: #green;
            } else if(tp_comportamento='MODERADO') {
                draw circle(3) color: #blue border: #blue;
            } else {
                draw circle(3) color: #red border: #red;
            }
        }
    }
}

species Bairro {
    aspect geom {
        draw shape color: #gray border: #black;
    }
}

experiment "VisualizacaoCompleta" type: gui {
    output {
        display "Mapa" type: opengl {
            species Bairro aspect: geom;
            species Residencia aspect: base;
        }
        
        display "Graficos" type: java2D {
            chart "Monthly Consumption - All Scenarios" type: series 
                   y_label: "Consumption (m^3)" x_label: "Month" size: {1.0, 1.0} {
                
                // Base Scenarios (No Income Factor)
                data "C I: Uniform Pop" value: consumo_anual_total_cI color: #blue;
                data "C II: Environmentalists Only" value: consumo_anual_total_cII color: #green;
                data "C III: Wasteful Only" value: consumo_anual_total_cIII color: #red;
                
                // Uniform Pop + Income Scenarios
                data "C IV: Unif Pop + Linear Income" value: consumo_anual_total_cIV color: #orange;
                data "C V: Unif Pop + Equilibrium Income" value: consumo_anual_total_cV color: #purple;
                data "C VI: Unif Pop + Disequilibrium Income" value: consumo_anual_total_cVI color: #brown;
                
                // Random Pop + Income Scenarios
                data "C VII: Rand Pop + Linear Income" value: consumo_anual_total_cVII color: #orange ;
                data "C VIII: Rand Pop + Equilibrium Income" value: consumo_anual_total_cVIII color: #purple ;
                data "C IX: Rand Pop + Disequilibrium Income" value: consumo_anual_total_cIX color: #brown ;
                
                // Environmentalists + Income Scenarios
                data "C X: Env + Linear Income" value: consumo_anual_total_cX color: #cyan;
                data "C XI: Env + Equilibrium Income" value: consumo_anual_total_cXI color: #magenta;
                data "C XII: Env + Disequilibrium Income" value: consumo_anual_total_cXII color: #pink;
                
                // Wasteful + Income Scenarios
                data "C XIII: Wasteful + Linear Income" value: consumo_anual_total_cXIII color: #darkgreen;
                data "C XIV: Wasteful + Equilibrium Income" value: consumo_anual_total_cXIV color: #darkred;
                data "C XV: Wasteful + Disequilibrium Income" value: consumo_anual_total_cXV color: #darkblue;
                
                // Random Income Scenarios
                data "C XVI: Unif Pop + Rand Linear Income" value: consumo_anual_total_cXVI color: #teal;
                data "C XVII: Unif Pop + Rand Equilibrium Income" value: consumo_anual_total_cXVII color: #olive;
                data "C XVIII: Unif Pop + Rand Disequilibrium Income" value: consumo_anual_total_cXVIII color: #maroon;
            }
        }
        
        // Monitors
        monitor "Year/Month" value: string(mes_corrente) + "/" + string(ano_corrente);
        monitor "Total Residences" value: total_residencias;
        monitor "C I (Base)" value: consumo_anual_total_cI[length(consumo_anual_total_cI)-1] color: #blue;
        monitor "C IV (Linear Income)" value: consumo_anual_total_cIV[length(consumo_anual_total_cIV)-1] color: #orange;
        monitor "C V (Equilibrium Income)" value: consumo_anual_total_cV[length(consumo_anual_total_cV)-1] color: #purple;
        monitor "C VI (Disequilibrium Income)" value: consumo_anual_total_cVI[length(consumo_anual_total_cVI)-1] color: #brown;
        monitor "C XIII (Wasteful Linear)" value: consumo_anual_total_cXIII[length(consumo_anual_total_cXIII)-1] color: #darkgreen;
    }
}

experiment "Visualizacao" type: gui {
    output {
        display "Mapa" type: opengl {
            species Bairro aspect: geom;
            species Residencia aspect: base;
        }
        
        display "Graficos" type: java2D {
            chart "Monthly Consumption Forecast" type: series y_label: "Consumption (m^3)" x_label: "Month" {
                // Main Scenarios
                data "CI (Base)" value: consumo_anual_total_cI color: #blue;
                data "CII (Base)" value: consumo_anual_total_cII color: #green;
                data "CIII (Base)" value: consumo_anual_total_cIII color: #black;        
                data "CIV (Unif Pop + Linear Income)" value: consumo_anual_total_cIV color: #orange;
                data "CV (Unif Pop + Equilibrium Income)" value: consumo_anual_total_cV color: #purple;
                data "CVI (Unif Pop + Disequilibrium Income)" value: consumo_anual_total_cVI color: #brown;
                data "CIII (Wasteful Only)" value: consumo_anual_total_cIII color: #red;
                data "Residences Standard Income" value: residencias_com_renda_padarao color: #black;
            }
        }   
        
        monitor "Total Residences" value: total_residencias;
        monitor "Environmentalists" value: total_ambientalistas color: #green;
        monitor "Wasteful" value: total_perdularios color: #red;
        monitor "Moderates" value: total_moderados color: #blue;    
        monitor "No Data Residences" value: residencias_sem_consumo color: #orange;
        monitor "Residences Standard Income" value: residencias_com_renda_padarao color: #black;
    }
}

experiment "Simulacao" type: batch {
    output {
        monitor "Year" value: ano_corrente;
        monitor "Month" value: mes_corrente;
        monitor "Consumpt CIV (Linear Income)" value: consumo_anual_total_cIV;
        monitor "Consumpt CV (Equilibrium Income)" value: consumo_anual_total_cV;
        monitor "Consumpt CVI (Disequilibrium Income)" value: consumo_anual_total_cVI;
        monitor "No Data Residences" value: residencias_sem_consumo color: #orange;
        monitor "Residences Standard Income" value: residencias_com_renda_padarao color: #black;
    }
}
    