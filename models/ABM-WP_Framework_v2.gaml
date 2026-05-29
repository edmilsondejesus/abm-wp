model ABMSWPSimulacao

global {
	// Definição do Teto de Consumo (Saturation Point) - 250 L/pessoa/dia - será sobrescrito pelo 99th percentil do consumo máximo medido no parametro de entrada.
	float teto_consumo_diario <- 250.0;
    
    // limite_minimo_consumo/person/day (WHO, 2020)
    float limite_minimo_oms <- 20.0;
    
    string ano_referencia_dados <- "2025";  //2025 ou 2015
    int ano_geracao_int <- int(ano_referencia_dados);
    string ano_geracao_inicio <- string(ano_geracao_int + 1);
    string ano_geracao_fim <- string(ano_geracao_int + 11);
    
    string nome_arquivo_simulacao_passado <- "simulacao_hindcasting";
    string nome_arquivo_simulacao_futuro <- "consumo_previsto_todos_cenarios";
    
    string arquivo_parametro_teto_consumo <- "../includes/parametros_teto_consumo_" + ano_referencia_dados + ".csv";
    string arquivo_comparativo_perfil_cenario <- "../resultados/comparativo_perfil_cenarios_qgis_" + ano_geracao_inicio + "_" + string(int(ano_geracao_fim)-1) + ".csv";
    string arquivo_parametro_renda_calculado <- "../includes/parametros_renda_calculados_" + ano_referencia_dados + ".csv";
    string arquivo_consumo_previsto_todos_cenarios;
    string arquivo_media_consumo_por_perfil <- "../resultados/medias_consumo_por_perfil_" + ano_referencia_dados + ".csv";
    string arquivo_consumo_medio_12m <- "../includes/Tabela_consumo_medio_Itapua_" + ano_referencia_dados + "_12m.csv";
    string arquivo_consumidores_itapua_comportamento_e_renda <- "../includes/Tabela_consumidores_Itapua_com_setor_comportamento_e_renda_" + ano_referencia_dados + "_ajustado.csv";
    
    string file_teto_consumo <- arquivo_parametro_teto_consumo;
    
    // Dados preparados pelo AnalyserAgent para as famílias
    map<string, float> parametros_globais_preparados;
    list<float> tendencia_consumo_historico;
    float elasticidade_media_renda <- 0.0;
    list<float> fator_sazonal_mensal;
    
    // Fila de previsões para o CommunicationAgent
    list<map<string, string>> fila_previsoes_recebidas;
    bool consolidacao_em_andamento <- false;
    
    // Arquivos de saída do CommunicationAgent
    string arquivo_previsoes_consolidadas;
    string arquivo_resumo_executivo;
    
    float round_to(float valor, int casas) {
    	float multiplicador <- 10 ^ casas;
    	return round(valor * multiplicador) / multiplicador;
	}
    
    // Action para carregar o teto de consumo do CSV
    action carregar_parametros_teto_consumo {
        if (file_exists(file_teto_consumo)) {
            csv_file arquivo_teto <- csv_file(file_teto_consumo, ";", true);
            matrix dados_teto <- matrix(arquivo_teto);
        
            loop i from: 0 to: dados_teto.rows - 1 {
                string nome_param <- string(dados_teto[0, i]);
                float valor_param <- float(dados_teto[1, i]);
            
                if (nome_param = 'teto_consumo_percentil_99') {
                    teto_consumo_diario <- valor_param;
                    write "--- TETO DE CONSUMO CARREGADO ---";
                    write "(99º percentil): " + teto_consumo_diario + " L/pessoa/dia";
                }
            }
        } 
    }
    
    float dias_no_mes <- 30.5;
    
    string path_qgis_export <- arquivo_comparativo_perfil_cenario;
    string scenario_id <- "CI"; 

    action inicializar_csv_qgis {
        string cabecalho <- "SK_MATRICULA,CD_SETOR,TP_COMPORTAMENTO,NN_MEDIA_CONSUMO,NN_CONSUMO_DIARIO,NN_MORADORES_ANALISE,NM_CENARIO,TP_NOVO_COMPORTAMENTO,NN_NOVA_MEDIA_CONSUMO,NN_NOVO_CONSUMO_DIARIO,NN_NOVO_MORADORES_ANALISE";
        save cabecalho type: "text" to: path_qgis_export;
    }
    
    float limite_baixa_renda <- 2000.0; 
    float limite_alta_renda <- 5000.0;  
    float sensibilidade_renda <- 0.0001; 
    float intercepto_base <- 10.0;      
    
    string file_params <- arquivo_parametro_renda_calculado;
    
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
                if (nome_param = 'teto_consumo_diario') { teto_consumo_diario <- valor_param; }
            }
            write "--- PARÂMETROS DE RENDA ---";
            write "Limite Baixa: " + limite_baixa_renda + " | Limite Alta: " + limite_alta_renda;
            write "Sensibilidade (k): " + sensibilidade_renda;
            write "teto consumo diário (l/p/day): " + teto_consumo_diario;            
        } 
    }
    
    string file_medias <- arquivo_media_consumo_por_perfil;
    csv_file arquivo_medias <- csv_file(file_medias, ";", true);
    
    float media_ambientalista <- 0.0;
    float media_perdulario <- 0.0;
    float media_moderado <- 0.0;
    
    float fator_conversao_mensal <- 30.5 / 1000;
    
    int total_residencias <- 0;
    int total_ambientalistas <- 0;
    int total_perdularios <- 0;
    int total_moderados <- 0;
    int residencias_sem_consumo <- 0;
    int residencias_com_renda_padarao <- 0;
    list<string> matriculas_sem_consumo <- [];
    
    list<int> historico_total_residencias <- [];
    list<int> historico_ambientalistas <- [];
    list<int> historico_perdularios <- [];
    list<int> historico_moderados <- [];
    
    string file_path <- arquivo_consumidores_itapua_comportamento_e_renda;
    string consumo_file <- arquivo_consumo_medio_12m;
    string shapefile_CD20220_path_prj <- "31984";
    file BA_setores_CD20220_shape_file <- shape_file("../includes/maps/Itapua13.shp", shapefile_CD20220_path_prj, true);
    
    csv_file arquivo <- csv_file(file_path, ";", true);
    csv_file arquivo_consumo <- csv_file(consumo_file, ";", true);
    
    string shapefile_path <- "../includes/maps/LIMITE_BAIRRO.shp";
    string shapefile_path_prj <- "31984";
    file shapefile <- shape_file(shapefile_path, shapefile_path_prj, true);
    geometry shape <- envelope(BA_setores_CD20220_shape_file);
    
    int meses_simulacao <- 120;
    int ano_corrente <- int(ano_geracao_inicio);
    int mes_corrente <- 1;
    list<int> anos;
    
    list<float> taxas_crescimento_mensal;
    list<float> percentuais_aumento_renda;
    
    float probabilidade_crescimento_aleatorio <- 0.7;
    
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
    list<float> consumo_anual_total_cXVI <- [];
    list<float> consumo_anual_total_cXVII <- [];
    list<float> consumo_anual_total_cXVIII <- [];
    
    list<float> dados_processados <- [];
    list<float> previsoes_consumo <- [];
    list<float> relatorio_final <- [];
    
    map<string, float> map_consumo_real_12m <- [];

    action carregar_medias_arquivo {
        matrix dados_matrix <- matrix(arquivo_medias);
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
    }
    
    // ============================================================
    // ANALYSER AGENT (GLOBAL) - PREPARA DADOS PARA AS FAMÍLIAS
    // ============================================================
    action analiser_preparar_dados {
        write "=== AnalyserAgent: Preparando dados para as famílias ===";
        
        // 1. Prepara parâmetros de renda
        parametros_globais_preparados <- map([]);
        parametros_globais_preparados["limite_baixa_renda"] <- limite_baixa_renda;
        parametros_globais_preparados["limite_alta_renda"] <- limite_alta_renda;
        parametros_globais_preparados["sensibilidade_renda"] <- sensibilidade_renda;
        parametros_globais_preparados["intercepto_base"] <- intercepto_base;
        parametros_globais_preparados["teto_consumo_diario"] <- teto_consumo_diario;
        parametros_globais_preparados["elasticidade_media"] <- elasticidade_media_renda;
        
        // 2. Prepara fatores sazonais (12 meses)
        fator_sazonal_mensal <- [];
        loop i from: 0 to: 11 {
            float fator <- 1.0;
            if (i = 0 or i = 11) { fator <- 0.95; }      // Janeiro/Dezembro (férias - menor consumo)
            else if (i = 1 or i = 2) { fator <- 0.98; }   // Fevereiro/Março
            else if (i = 5 or i = 6) { fator <- 1.05; }   // Julho/Agosto (inverno - maior consumo)
            else if (i = 8 or i = 9) { fator <- 1.03; }   // Outubro/Novembro
            else { fator <- 1.0; }
            fator_sazonal_mensal <- fator_sazonal_mensal + [fator];
        }
        
        // 3. Calcula elasticidade média da renda baseada nos dados das residências
        float soma_elasticidade <- 0.0;
        int contador <- 0;
        
        ask Residencia {
            if (vl_renda_cI > 0 and consumo_atual_cI > 0) {
                float consumo_per_capita <- (consumo_atual_cI * 1000) / nn_moradores / 30.5;
                float elasticidade <- (consumo_per_capita / limite_minimo_oms) / (vl_renda_cI / limite_baixa_renda);
                soma_elasticidade <- soma_elasticidade + elasticidade;
                contador <- contador + 1;
            }
        }
        
        if (contador > 0) {
            elasticidade_media_renda <- soma_elasticidade / contador;
            parametros_globais_preparados["elasticidade_media"] <- elasticidade_media_renda;
        }
        
        write "AnalyserAgent: Dados preparados com sucesso!";
        write "  Elasticidade média da renda: " + round_to(elasticidade_media_renda, 4);
        write "  Fatores sazonais: " + fator_sazonal_mensal;
    }
    
    // ============================================================
    // COMMUNICATION AGENT (GLOBAL) - CONSOLIDA PREVISÕES
    // ============================================================
    action registrar_previsao(string matricula, string cenario, float valor_previsto, string perfil) {
        map<string, string> registro <- map([]);
        registro["matricula"] <- matricula;
        registro["cenario"] <- cenario;
        registro["valor_previsto"] <- string(valor_previsto);
        registro["perfil"] <- perfil;
        registro["ano"] <- string(ano_corrente);
        registro["mes"] <- string(mes_corrente);
        
        fila_previsoes_recebidas <- fila_previsoes_recebidas + [registro];
    }
    
    action communication_consolidar_previsoes {
        if (consolidacao_em_andamento) { return; }
        if (empty(fila_previsoes_recebidas)) { return; }
        
        consolidacao_em_andamento <- true;
        
        write "=== CommunicationAgent: Consolidando " + length(fila_previsoes_recebidas) + " previsões ===";
        
        // Estruturas para agregação
        map<string, float> somas_por_cenario;
        map<string, int> contagens_por_cenario;
        map<string, float> medias_por_cenario;
        map<string, float> soma_quadrados_por_cenario;
        
        // Processa cada previsão
        loop registro over: fila_previsoes_recebidas {
            string cenario <- registro["cenario"];
            float valor <- float(registro["valor_previsto"]);
            
            if (!(cenario in somas_por_cenario)) {
                somas_por_cenario[cenario] <- 0.0;
                contagens_por_cenario[cenario] <- 0;
                soma_quadrados_por_cenario[cenario] <- 0.0;
            }
            
            somas_por_cenario[cenario] <- somas_por_cenario[cenario] + valor;
            contagens_por_cenario[cenario] <- contagens_por_cenario[cenario] + 1;
            soma_quadrados_por_cenario[cenario] <- soma_quadrados_por_cenario[cenario] + (valor * valor);
        }
        
        // Calcula médias e desvios
        loop cenario over: somas_por_cenario.keys {
            int n <- contagens_por_cenario[cenario];
            float soma <- somas_por_cenario[cenario];
            medias_por_cenario[cenario] <- soma / n;
        }
        
        // Gera arquivo CSV consolidado
        arquivo_previsoes_consolidadas <- "../resultados/previsoes_consolidadas_" + ano_referencia_dados + "_" + string(ano_corrente) + "_" + string(mes_corrente) + ".csv";
        bool cabecalho_escrito <- file_exists(arquivo_previsoes_consolidadas);
        
        string linha;
        
        if (!cabecalho_escrito) {
            string cabecalho <- "Ano;Mes;Cenario;Num_Familias;Soma_Prevista_m3;Media_Prevista_m3;Desvio_Previsto";
            save cabecalho type: "text" to: arquivo_previsoes_consolidadas;
        }
        
        loop cenario over: somas_por_cenario.keys {
            int n <- contagens_por_cenario[cenario];
            float soma <- somas_por_cenario[cenario];
            float media <- medias_por_cenario[cenario];
            float variancia <- (soma_quadrados_por_cenario[cenario] / n) - (media * media);
            float desvio <- sqrt(abs(variancia));
            
            linha <- string(ano_corrente) + ";" +
                     string(mes_corrente) + ";" +
                     cenario + ";" +
                     string(n) + ";" +
                     replace(string(round_to(soma, 2)), ".", ",") + ";" +
                     replace(string(round_to(media, 2)), ".", ",") + ";" +
                     replace(string(round_to(desvio, 2)), ".", ",");
            
            save linha type: "text" to: arquivo_previsoes_consolidadas;
            
            write "  " + cenario + ": " + n + " famílias | Soma: " + round_to(soma, 2) + " m³ | Média: " + round_to(media, 2);
        }
        
        // Gera resumo executivo
        arquivo_resumo_executivo <- "../resultados/resumo_executivo_" + ano_referencia_dados + "_" + string(ano_corrente) + ".txt";
        
        string conteudo <- "=== RESUMO EXECUTIVO - " + mes_corrente + "/" + ano_corrente + " ===\n";
        conteudo <- conteudo + "Ano referência: " + ano_referencia_dados + "\n";
        conteudo <- conteudo + "Total de previsões recebidas: " + length(fila_previsoes_recebidas) + "\n";
        conteudo <- conteudo + "Total de residências: " + total_residencias + "\n";
        
        float cobertura <- (length(fila_previsoes_recebidas) / (total_residencias * 18)) * 100.0;
        conteudo <- conteudo + "Taxa de cobertura: " + round_to(cobertura, 1) + "%\n\n";
        
        conteudo <- conteudo + "=== PREVISÕES POR CENÁRIO ===\n";
        loop cenario over: somas_por_cenario.keys {
            conteudo <- conteudo + cenario + ": " + round_to(somas_por_cenario[cenario], 2) + " m³ (" + contagens_por_cenario[cenario] + " famílias)\n";
        }
        
        if (file_exists(arquivo_resumo_executivo)) {
            save conteudo type: "text" to: arquivo_resumo_executivo;
        } else {
            save conteudo type: "text" to: arquivo_resumo_executivo;
        }
        
        // Limpa fila para o próximo ciclo
        fila_previsoes_recebidas <- [];
        consolidacao_em_andamento <- false;
        
        write "CommunicationAgent: Consolidação concluída!";
    }
    
    action communication_gerar_relatorio_final {
        string caminho_final <- "../resultados/relatorio_final_comunicacao_" + ano_referencia_dados + ".txt";
        
        string conteudo <- "=== RELATÓRIO FINAL DO COMMUNICATION AGENT ===\n";
        conteudo <- conteudo + "Período: " + ano_geracao_inicio + " a " + string(int(ano_geracao_fim)-1) + "\n";
        conteudo <- conteudo + "Ano referência dados: " + ano_referencia_dados + "\n\n";
        
        if (!empty(consumo_anual_total_cI)) {
            float ci_inicial <- consumo_anual_total_cI[0];
            float ci_final <- consumo_anual_total_cI[length(consumo_anual_total_cI)-1];
            float crescimento_total <- ((ci_final - ci_inicial) / ci_inicial) * 100.0;
            
            conteudo <- conteudo + "=== CENÁRIO BASE (CI) ===\n";
            conteudo <- conteudo + "Consumo inicial: " + round_to(ci_inicial, 2) + " m³\n";
            conteudo <- conteudo + "Consumo final: " + round_to(ci_final, 2) + " m³\n";
            conteudo <- conteudo + "Crescimento total: " + round_to(crescimento_total, 2) + "%\n\n";
            
            if (!empty(consumo_anual_total_cIV)) {
                float civ_final <- consumo_anual_total_cIV[length(consumo_anual_total_cIV)-1];
                float cv_final <- consumo_anual_total_cV[length(consumo_anual_total_cV)-1];
                float cvi_final <- consumo_anual_total_cVI[length(consumo_anual_total_cVI)-1];
                
                conteudo <- conteudo + "=== COMPARATIVO FINAL ===\n";
                conteudo <- conteudo + "CI (Base): " + round_to(ci_final, 2) + " m³\n";
                conteudo <- conteudo + "CIV (Renda Linear): " + round_to(civ_final, 2) + " m³ (dif: " + round_to(((civ_final - ci_final)/ci_final)*100, 2) + "%)\n";
                conteudo <- conteudo + "CV (Renda Equilíbrio): " + round_to(cv_final, 2) + " m³ (dif: " + round_to(((cv_final - ci_final)/ci_final)*100, 2) + "%)\n";
                conteudo <- conteudo + "CVI (Renda Desequilíbrio): " + round_to(cvi_final, 2) + " m³ (dif: " + round_to(((cvi_final - ci_final)/ci_final)*100, 2) + "%)\n";
            }
        }
        
        save conteudo type: "text" to: caminho_final;
        write "CommunicationAgent: Relatório final salvo em " + caminho_final;
    }
    
    // ============================================================
    // INIT PRINCIPAL
    // ============================================================
    init {  
        if(ano_referencia_dados = "2015"){
            arquivo_consumo_previsto_todos_cenarios <- "../resultados/" + nome_arquivo_simulacao_passado + "_" + ano_geracao_inicio + "_" + string(int(ano_geracao_fim)-1) + ".csv";
            anos <- [2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026];
            
            taxas_crescimento_mensal <- [
                0.00034, 0.00034, 0.00035, 0.00034, 0.00032,
                0.00030, 0.00029, 0.00027, 0.00025, 0.00023, 0.00023
            ];
            
            percentuais_aumento_renda <- [
                -0.040694617, 0.005083616, 0.005261762, 0.009585339, -0.045615004,
                0.039183815, 0.021387542, 0.004332235, 0.045954924, 0.011194, 0.011194
            ];
        } else if(ano_referencia_dados = "2025"){
            arquivo_consumo_previsto_todos_cenarios <- "../resultados/" + nome_arquivo_simulacao_futuro + "_" + ano_geracao_inicio + "_" + string(int(ano_geracao_fim)-1) + ".csv";
            anos <- [2026, 2027, 2028, 2029, 2030, 2031, 2032, 2033, 2034, 2035, 2036];
            
            taxas_crescimento_mensal <- [0.00023, 0.00020, 0.00018, 0.00016, 0.00014, 0.00012, 0.00009, 0.00007, 0.00004, 0.00001, -0.00001];
            
            percentuais_aumento_renda <- [
                0.008365, 0.017716, 0.022153, 0.001347, 0.011121,
                0.010602, 0.022184, 0.006014, 0.018149, 0.009987, 0.009987
            ];
        } else {
            error "Ano referência não suportado: " + ano_referencia_dados + ". Use apenas 2015 ou 2025.";
        }
        
        do carregar_parametros_renda;
        do inicializar_csv_qgis;
        
        create Bairro from: BA_setores_CD20220_shape_file;
        
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
            
            float renda_inicial <- float(self["VL_RENDA_MEDIA_RESPONSAVEL"]);
            
            if (renda_inicial <= 0.0) {
                residencias_com_renda_padarao <- residencias_com_renda_padarao + 1;
            }
            
            nn_moradores <- nn_moradores_inicial;
            
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
            vl_renda_cXVI <- renda_inicial;
            vl_renda_cXVII <- renda_inicial;
            vl_renda_cXVIII <- renda_inicial;
            
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
            vl_renda_inicial_cXVI <- renda_inicial;
            vl_renda_inicial_cXVII <- renda_inicial;
            vl_renda_inicial_cXVIII <- renda_inicial;
            
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
            consumo_atual_cXVI <- consumo_inicial;
            consumo_atual_cXVII <- consumo_inicial;
            consumo_atual_cXVIII <- consumo_inicial;
        }
        
        // PREPARA DADOS (ANALYSER AGENT)
        do analiser_preparar_dados;
        
        // CRIA PREDITOR AGENT PARA CADA RESIDENCIA (já criado dentro da species)
        // CRIA COMMUNICATION AGENT GLOBAL
        create CommunicationAgentGlobal;
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
    
    reflex atualizar_anualmente when: mes_corrente = 1 and ano_corrente > int(ano_geracao_inicio) {
        ask Residencia {
            do atualizar_renda_linear_cIV;
            do atualizar_renda_linear_cVII;
            do atualizar_renda_linear_cX;
            do atualizar_renda_linear_cXIII;
            
            do atualizar_renda_equilibrio_cV;
            do atualizar_renda_equilibrio_cVIII;
            do atualizar_renda_equilibrio_cXI;
            do atualizar_renda_equilibrio_cXIV;
            
            do atualizar_renda_desequilibrio_cVI;
            do atualizar_renda_desequilibrio_cIX;
            do atualizar_renda_desequilibrio_cXII;
            do atualizar_renda_desequilibrio_cXV;
            
            do atualizar_renda_aleatoria_linear_cXVI;
            do atualizar_renda_aleatoria_equilibrio_cXVII;
            do atualizar_renda_aleatoria_desequilibrio_cXVIII;
        }
    }
    
    reflex calcular_consumo_mensal {    
        ask Residencia {
            do prever_consumo_todos_cenarios;
        }
        
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
        
        mes_corrente <- mes_corrente + 1;
        if (mes_corrente > 12) {
            mes_corrente <- 1;
            ano_corrente <- ano_corrente + 1;
        }
        
        ask Residencia {            
            if(ano_corrente = int(ano_geracao_fim)){
                do exportar_resultados_qgis;            
            }
        }
        
        // CONSOLIDA PREVISÕES (COMMUNICATION AGENT)
        do communication_consolidar_previsoes;
    }
    
    reflex stop_simulation when: ano_corrente = int(ano_geracao_fim) {
        write "Parar simulação";
        do gerar_csv_consumo;
        do communication_gerar_relatorio_final;
        do pause;
    }
    
    action gerar_csv_consumo {
        string caminho_csv <- arquivo_consumo_previsto_todos_cenarios;
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
        
        int num_meses <- length(consumo_anual_total_cI);
        
        loop i from: 0 to: num_meses - 1 {
            int mes <- (i mod 12) + 1;
            int ano <- int(ano_geracao_inicio) + int(i / 12);
            string mes_ano <- string(mes) + "/" + string(ano);
            
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
        
        save conteudo_csv type: "text" to: caminho_csv;
        write "Arquivo CSV gerado com todos os cenários: " + caminho_csv;
        write "Total de meses registrados: " + num_meses;
    }
}

// ============================================================
// SPECIES CONSUMORESIDENCIA
// ============================================================
species ConsumoResidencia {
    string sk_matricula;
    int am_referencia;
    float nn_consumo;
}

// ============================================================
// SPECIES BAIRRO
// ============================================================
species Bairro {
    aspect geom {
        draw shape color: #gray border: #black;
    }
}

// ============================================================
// SPECIES COMMUNICATION AGENT GLOBAL
// ============================================================
species CommunicationAgentGlobal {
    // Agente global único para consolidar previsões
    
    init {
        write "CommunicationAgentGlobal: Agente de comunicação criado!";
    }
    
    action receber_previsao(string matricula, string cenario, float valor_previsto, string perfil) {
        map<string, string> registro <- map([]);
        registro["matricula"] <- matricula;
        registro["cenario"] <- cenario;
        registro["valor_previsto"] <- string(valor_previsto);
        registro["perfil"] <- perfil;
        registro["ano"] <- string(ano_corrente);
        registro["mes"] <- string(mes_corrente);
        
        fila_previsoes_recebidas <- fila_previsoes_recebidas + [registro];
    }
}

// ============================================================
// PREDICTOR AGENT (SPECIES SEPARADA)
// ============================================================
species PredictorAgent {
    // Referência para a residência pai
    Residencia minha_residencia;
    
    // Dados locais (cache)
    string minha_matricula;
    string meu_perfil;
    float meu_consumo_atual;
    float minha_renda_atual;
    float meus_moradores;
    list<float> meu_historico_consumo;
    
    init {
        meu_historico_consumo <- [];
    }
    
    action atualizar_dados_locais {
        if (minha_residencia != nil) {
            minha_matricula <- minha_residencia.sk_matricula;
            meu_perfil <- minha_residencia.tp_comportamento;
            meu_consumo_atual <- minha_residencia.consumo_atual_cI;
            minha_renda_atual <- minha_residencia.vl_renda_cI;
            meus_moradores <- minha_residencia.nn_moradores;
        }
    }
    
    action prever_consumo {
        float sensibilidade <- parametros_globais_preparados["sensibilidade_renda"];
        float teto <- parametros_globais_preparados["teto_consumo_diario"];
        float limite_baixa <- parametros_globais_preparados["limite_baixa_renda"];
        float limite_alta <- parametros_globais_preparados["limite_alta_renda"];
        
        int idx_mes <- mes_corrente - 1;
        float fator_sazonal <- 1.0;
        if (idx_mes >= 0 and idx_mes < length(fator_sazonal_mensal)) {
            fator_sazonal <- fator_sazonal_mensal[idx_mes];
        }
        
        int indice_ano <- ano_corrente - int(ano_geracao_inicio);
        float taxa_crescimento <- 0.0;
        if (indice_ano >= 0 and indice_ano < length(taxas_crescimento_mensal)) {
            taxa_crescimento <- taxas_crescimento_mensal[indice_ano];
        }
        
        if (minha_residencia != nil) {
            // Cenário CI (Base)
            float previsao_ci <- meu_consumo_atual * (1 + taxa_crescimento) * fator_sazonal;
            previsao_ci <- aplicar_teto(previsao_ci, meus_moradores, teto);
            minha_residencia.consumo_atual_cI <- previsao_ci;
            
            // Cenário CII (Ambientalistas)
            if (meu_perfil = "AMBIENTALISTA") {
                float previsao_cii <- meu_consumo_atual * (1 + taxa_crescimento) * fator_sazonal;
                previsao_cii <- aplicar_teto(previsao_cii, meus_moradores, teto);
                minha_residencia.consumo_atual_cII <- previsao_cii;
            }
            
            // Cenário CIII (Perdularios)
            if (meu_perfil = "PERDULARIO") {
                float previsao_ciii <- meu_consumo_atual * (1 + taxa_crescimento) * fator_sazonal;
                previsao_ciii <- aplicar_teto(previsao_ciii, meus_moradores, teto);
                minha_residencia.consumo_atual_cIII <- previsao_ciii;
            }
            
            // Registra no histórico
            meu_historico_consumo <- meu_historico_consumo + [meu_consumo_atual];
            
            // Mantém apenas últimos 24 meses
            if (length(meu_historico_consumo) > 24) {
                list<float> nova_lista <- [];
                int inicio <- length(meu_historico_consumo) - 24;
                loop i from: inicio to: length(meu_historico_consumo)-1 {
                    nova_lista <- nova_lista + [meu_historico_consumo[i]];
                }
                meu_historico_consumo <- nova_lista;
            }
        }
    }
    
    float aplicar_teto(float consumo_mensal_m3, float num_moradores, float teto) {
        float consumo_diario_perc_capita <- (consumo_mensal_m3 * 1000) / (num_moradores * 30.5);
        if (consumo_diario_perc_capita > teto) {
            return (teto * num_moradores * 30.5) / 1000;
        }
        return consumo_mensal_m3;
    }
}



// ============================================================
// SPECIES RESIDENCIA
// ============================================================
species Residencia {
    string sk_matricula;
    string cd_setor;
    float nn_media_consumo;
    float nn_consumo_diario;
    string nm_subcategoria;
    string tp_comportamento;
    float latitude;  
    float longitude;
    
    PredictorAgent meu_predictor;
    
    float nn_moradores;
    float nn_moradores_inicial;
    int st_piscina;
    
    float consumo_mensal_cI; float consumo_mensal_cII; float consumo_mensal_cIII;
    float consumo_mensal_cIV; float consumo_mensal_cV; float consumo_mensal_cVI;
    float consumo_mensal_cVII; float consumo_mensal_cVIII; float consumo_mensal_cIX;
    float consumo_mensal_cX; float consumo_mensal_cXI; float consumo_mensal_cXII;
    float consumo_mensal_cXIII; float consumo_mensal_cXIV; float consumo_mensal_cXV;
    float consumo_mensal_cXVI; float consumo_mensal_cXVII; float consumo_mensal_cXVIII;
    
    string tp_novo_comportamento;
    float nn_nova_media_consumo;
    float nn_novo_consumo_diario;
    
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
    
    bool tem_crescimento_aleatorio <- flip(probabilidade_crescimento_aleatorio);
    
    
    // Instancia o PredictorAgent dentro de cada residência
    init {
        // Cria o PredictorAgent e associa a esta residência
		meu_predictor <- one_of(PredictorAgent);
        if (meu_predictor != nil) {
        	
            meu_predictor.minha_residencia <- self;
			ask meu_predictor {
    		do atualizar_dados_locais;
			}        
		}
    }
    
    // Reflex para executar a previsão no início de cada mês
    reflex executar_previsao {
        if (meu_predictor != nil) {
        	ask meu_predictor {
    			do atualizar_dados_locais;
    			do prever_consumo;
			}
        }
    }
    
    // ============================================================
    // FUNÇÕES EXISTENTES (MANTIDAS)
    // ============================================================
    float get_taxa_crescimento_mensal {
        int indice_ano <- ano_corrente - int(ano_geracao_inicio);
        if (indice_ano >= 0 and indice_ano < length(taxas_crescimento_mensal)) {
            return taxas_crescimento_mensal[indice_ano];
        }
        return 0.0;
    }
    
    float get_percentual_aumento_renda {
        int indice_ano <- ano_corrente - int(ano_geracao_inicio);
        if (indice_ano >= 0 and indice_ano < length(percentuais_aumento_renda)) {
            return percentuais_aumento_renda[indice_ano];
        } else {
            return 0.0;
        }
    }
    
    float aplicar_limites_logicos(float consumo_bruto) {
        float consumo_min_vital <- (limite_minimo_oms * nn_moradores * dias_no_mes) / 1000;
        float consumo_max_tecnico <- (teto_consumo_diario * nn_moradores * dias_no_mes) / 1000;
        float valor_final <- max(consumo_bruto, consumo_min_vital);
        valor_final <- min(valor_final, consumo_max_tecnico);
        return valor_final;
    }
    
    action exportar_cenario(string nome_cen, float valor_final, float valor_nn_moradores) {
        nn_nova_media_consumo <- valor_final;
        nn_novo_consumo_diario <- (nn_nova_media_consumo * 1000 / valor_nn_moradores) / 30.5;
        
        if (nn_novo_consumo_diario < 100.0) {
            tp_novo_comportamento <- "AMBIENTALISTA";
        } else if (nn_novo_consumo_diario <= 121.5) {
            tp_novo_comportamento <- "MODERADO";
        } else {
            tp_novo_comportamento <- "PERDULARIO";
        }
        
        save [sk_matricula, cd_setor, tp_comportamento, nn_media_consumo, nn_consumo_diario, nn_moradores_inicial,
              nome_cen, tp_novo_comportamento, nn_nova_media_consumo, nn_novo_consumo_diario, valor_nn_moradores] 
        to: arquivo_comparativo_perfil_cenario type: "csv" rewrite: false;
    }
    
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
    
    action atualizar_moradores {
        float taxa_mensal <- get_taxa_crescimento_mensal();
        nn_moradores <- int(nn_moradores * (1 + taxa_mensal));
    }
    
    action atualizar_moradores_aleatorio {
        if (tem_crescimento_aleatorio) {
            float taxa_mensal <- get_taxa_crescimento_mensal();
            nn_moradores <- int(nn_moradores * (1 + taxa_mensal));
        }
    }
    
    // Income update actions (mantidas)
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
        if (tp_comportamento = 'AMBIENTALISTA') { 
            vl_renda_cX <- vl_renda_cX + (vl_renda_cX * percentual);
        }
    }
    action atualizar_renda_linear_cXIII {
        float percentual <- get_percentual_aumento_renda();
        if (tp_comportamento = 'PERDULARIO') {
            vl_renda_cXIII <- vl_renda_cXIII + (vl_renda_cXIII * percentual);
        }
    }
    
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
    
    action atualizar_renda_aleatoria_linear_cXVI {
        float percentual <- get_percentual_aumento_renda();
        float variacao <- rnd(-0.3, 0.3);
        float percentual_ajustado <- percentual * (1 + variacao);
        vl_renda_cXVI <- vl_renda_cXVI * (1 + percentual_ajustado);
    }
    
    action atualizar_renda_aleatoria_equilibrio_cXVII {
        float percentual <- get_percentual_aumento_renda();
        float fator_desigualdade <- 1.0;
        if (vl_renda_cXVII < limite_baixa_renda) { fator_desigualdade <- 1.1; } 
        else if (vl_renda_cXVII > limite_alta_renda) { fator_desigualdade <- 1.05; }
        float variacao <- rnd(0.05, 0.1);
        fator_desigualdade <- fator_desigualdade * (1 + variacao);
        vl_renda_cXVII <- vl_renda_cXVII * (1 + percentual * fator_desigualdade);
    }
    
    action atualizar_renda_aleatoria_desequilibrio_cXVIII {
        float percentual <- get_percentual_aumento_renda();
        float fator_desigualdade <- 1.0;
        if (vl_renda_cXVIII < limite_baixa_renda) { fator_desigualdade <- 1.05; } 
        else if (vl_renda_cXVIII > limite_alta_renda) { fator_desigualdade <- 1.1; }
        float variacao <- rnd(0.05, 0.1);
        fator_desigualdade <- fator_desigualdade * (1 + variacao);
        vl_renda_cXVIII <- vl_renda_cXVIII * (1 + percentual * fator_desigualdade);
    }
    
    action prever_consumo_todos_cenarios {
        float taxa_mensal <- get_taxa_crescimento_mensal();
        do atualizar_moradores; 
        float fator_pop <- (1 + taxa_mensal);
        
        float bruto_cI <- consumo_atual_cI * fator_pop;
        float bruto_cII <- (tp_comportamento = 'AMBIENTALISTA') ? (consumo_atual_cII * fator_pop) : consumo_atual_cII;
        float bruto_cIII <- (tp_comportamento = 'PERDULARIO') ? (consumo_atual_cIII * fator_pop) : consumo_atual_cIII;
        
        consumo_atual_cI <- aplicar_limites_logicos(bruto_cI);
        consumo_atual_cII <- aplicar_limites_logicos(bruto_cII);
        consumo_atual_cIII <- aplicar_limites_logicos(bruto_cIII);
        
        float fator_renda_cIV <- (1.0 + (vl_renda_cIV * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cIV * sensibilidade_renda));
        consumo_atual_cIV <- aplicar_limites_logicos(bruto_cI * fator_renda_cIV);
        
        float fator_renda_cV <- (1.0 + (vl_renda_cV * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cV * sensibilidade_renda));
        consumo_atual_cV <- aplicar_limites_logicos(bruto_cI * fator_renda_cV);
        
        float fator_renda_cVI <- (1.0 + (vl_renda_cVI * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cVI * sensibilidade_renda));
        consumo_atual_cVI <- aplicar_limites_logicos(bruto_cI * fator_renda_cVI);
        
        float base_aleatoria_bruta <- tem_crescimento_aleatorio ? bruto_cI : (bruto_cI / fator_pop);
        
        float fator_renda_cVII <- (1.0 + (vl_renda_cVII * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cVII * sensibilidade_renda));
        consumo_atual_cVII <- aplicar_limites_logicos(base_aleatoria_bruta * fator_renda_cVII);
        
        float fator_renda_cVIII <- (1.0 + (vl_renda_cVIII * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cVIII * sensibilidade_renda));
        consumo_atual_cVIII <- aplicar_limites_logicos(base_aleatoria_bruta * fator_renda_cVIII);
        
        float fator_renda_cIX <- (1.0 + (vl_renda_cIX * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cIX * sensibilidade_renda));
        consumo_atual_cIX <- aplicar_limites_logicos(base_aleatoria_bruta * fator_renda_cIX);
        
        if (tp_comportamento = 'AMBIENTALISTA') {
            float fator_renda_cX <- (1.0 + (vl_renda_cX * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cX * sensibilidade_renda));
            consumo_atual_cX <- aplicar_limites_logicos(bruto_cII * fator_renda_cX);
            
            float fator_renda_cXI <- (1.0 + (vl_renda_cXI * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXI * sensibilidade_renda));
            consumo_atual_cXI <- aplicar_limites_logicos(bruto_cII * fator_renda_cXI);
            
            float fator_renda_cXII <- (1.0 + (vl_renda_cXII * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXII * sensibilidade_renda));
            consumo_atual_cXII <- aplicar_limites_logicos(bruto_cII * fator_renda_cXII);
        } else {
            consumo_atual_cX <- aplicar_limites_logicos(bruto_cII);
            consumo_atual_cXI <- aplicar_limites_logicos(bruto_cII);
            consumo_atual_cXII <- aplicar_limites_logicos(bruto_cII);
        }
        
        if (tp_comportamento = 'PERDULARIO') {
            float fator_renda_cXIII <- (1.0 + (vl_renda_cXIII * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXIII * sensibilidade_renda));
            consumo_atual_cXIII <- aplicar_limites_logicos(bruto_cIII * fator_renda_cXIII);
            
            float fator_renda_cXIV <- (1.0 + (vl_renda_cXIV * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXIV * sensibilidade_renda));
            consumo_atual_cXIV <- aplicar_limites_logicos(bruto_cIII * fator_renda_cXIV);
            
            float fator_renda_cXV <- (1.0 + (vl_renda_cXV * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXV * sensibilidade_renda));
            consumo_atual_cXV <- aplicar_limites_logicos(bruto_cIII * fator_renda_cXV);
        } else {
            consumo_atual_cXIII <- aplicar_limites_logicos(bruto_cIII);
            consumo_atual_cXIV <- aplicar_limites_logicos(bruto_cIII);
            consumo_atual_cXV <- aplicar_limites_logicos(bruto_cIII);
        }
        
        float fator_renda_cXVI <- (1.0 + (vl_renda_cXVI * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXVI * sensibilidade_renda));
        consumo_atual_cXVI <- aplicar_limites_logicos(bruto_cI * fator_renda_cXVI * (1 + rnd(-0.15, 0.15)));
        
        float fator_renda_cXVII <- (1.0 + (vl_renda_cXVII * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXVII * sensibilidade_renda));
        consumo_atual_cXVII <- aplicar_limites_logicos(bruto_cI * fator_renda_cXVII * (1 + rnd(-0.15, 0.15)));
        
        float fator_renda_cXVIII <- (1.0 + (vl_renda_cXVIII * sensibilidade_renda)) / (1.0 + (vl_renda_inicial_cXVIII * sensibilidade_renda));
        consumo_atual_cXVIII <- aplicar_limites_logicos(bruto_cI * fator_renda_cXVIII * (1 + rnd(-0.15, 0.15)));
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

// ============================================================
// EXPERIMENTS
// ============================================================
experiment "VisualizacaoCompleta" type: gui {
    output {
        display "Mapa" type: opengl {
            species Bairro aspect: geom;
            species Residencia aspect: base;
        }
        
        display "Graficos" type: java2D {
            chart "Monthly Consumption - All Scenarios" type: series 
                   y_label: "Consumption (m^3)" x_label: "Month" size: {1.0, 1.0} {
                data "C I: Uniform Pop" value: consumo_anual_total_cI color: #blue;
                data "C II: Environmentalists Only" value: consumo_anual_total_cII color: #green;
                data "C III: Wasteful Only" value: consumo_anual_total_cIII color: #red;
                data "C IV: Unif Pop + Linear Income" value: consumo_anual_total_cIV color: #orange;
                data "C V: Unif Pop + Equilibrium Income" value: consumo_anual_total_cV color: #purple;
                data "C VI: Unif Pop + Disequilibrium Income" value: consumo_anual_total_cVI color: #brown;
                data "C VII: Rand Pop + Linear Income" value: consumo_anual_total_cVII color: #orange;
                data "C VIII: Rand Pop + Equilibrium Income" value: consumo_anual_total_cVIII color: #purple;
                data "C IX: Rand Pop + Disequilibrium Income" value: consumo_anual_total_cIX color: #brown;
                data "C X: Env + Linear Income" value: consumo_anual_total_cX color: #cyan;
                data "C XI: Env + Equilibrium Income" value: consumo_anual_total_cXI color: #magenta;
                data "C XII: Env + Disequilibrium Income" value: consumo_anual_total_cXII color: #pink;
                data "C XIII: Wasteful + Linear Income" value: consumo_anual_total_cXIII color: #darkgreen;
                data "C XIV: Wasteful + Equilibrium Income" value: consumo_anual_total_cXIV color: #darkred;
                data "C XV: Wasteful + Disequilibrium Income" value: consumo_anual_total_cXV color: #darkblue;
                data "C XVI: Unif Pop + Rand Linear Income" value: consumo_anual_total_cXVI color: #teal;
                data "C XVII: Unif Pop + Rand Equilibrium Income" value: consumo_anual_total_cXVII color: #olive;
                data "C XVIII: Unif Pop + Rand Disequilibrium Income" value: consumo_anual_total_cXVIII color: #maroon;
            }
        }
        
        monitor "Year/Month" value: string(mes_corrente) + "/" + string(ano_corrente);
        monitor "Total Residences" value: total_residencias;
        monitor "C I (Base)" value: consumo_anual_total_cI[length(consumo_anual_total_cI)-1] color: #blue;
        monitor "C IV (Linear Income)" value: consumo_anual_total_cIV[length(consumo_anual_total_cIV)-1] color: #orange;
        monitor "C V (Equilibrium Income)" value: consumo_anual_total_cV[length(consumo_anual_total_cV)-1] color: #purple;
        monitor "C VI (Disequilibrium Income)" value: consumo_anual_total_cVI[length(consumo_anual_total_cVI)-1] color: #brown;
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