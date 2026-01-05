########################################################
#                  Tratamento dos dados
########################################################
tratamento_de_dados <- function(dados) {
  
  # Pacotes
  require(dplyr)
  
  # Selecionar variáveis
  dados <- dados[, c(
    "comunidadeTradicional",
    "evolucaoCaso",
    "dataNascimento",
    "dataInicioSintomas",
    "classificacaoFinal",
    "municipioIBGE",
    "estadoIBGE",
    "estadoNotificacao",
    "idade",
    "profissionalSaude",
    "sexo",
    "racaCor",
    "condicoes",
    "triagemPopulacaoEspecifica",
    "codigoTriagemPopulacaoEspecifica",
    "qualAntiviral",
    "codigoQualAntiviral",
    "anoEpiSintomas",
    "semEpiSintomas"
  )]
  
  # Renomear categorias das variáveis
  dados$evolucaoCaso[is.na(dados$evolucaoCaso)] <- 9
  dados$racaCor[is.na(dados$racaCor)] <- 9
  
  log_info('Criando variável caso_novo')
  
  # Criar variável caso novo
  dados$caso_novo <- ifelse(
    dados$classificacaoFinal %in% c(1, 2, 5, 6) &
      dados$dataInicioSintomas <= "2022-10-31", 1,
    ifelse(
      dados$classificacaoFinal %in% c(1, 2) & 
        dados$dataInicioSintomas > "2022-10-31", 1, 0
    )
  )
  
  dados$caso_novo[is.na(dados$caso_novo)] <- 9
  
  # Criar variável faixa etária
  log_info('Criando variável faixa etária')
  
  dados <- dados |>
    
    mutate(idade2 = time_length(interval(dataNascimento, dataInicioSintomas), "months")) |>
    
    mutate(faixa_etaria = case_when(                                                                                                                         # Cria a coluna 'faixa_etaria' corrigindo os intervalos
      idade2 >= 0 & idade2 <= 6 ~ 1, # "0 a 06 meses",
      idade2 > 7 & idade2 <= 12 ~ 2, # "07 meses a 01 ano",
      idade2 > 12 & idade2 <= 48 ~ 3, # "02 a 04 anos", 
      idade2 > 48 & idade2 <= 120 ~ 4, # "05 a 10 anos",        
      idade2 > 120 & idade2 <= 180 ~ 5, # "11 a 15 anos",       
      idade2 > 180 & idade2 <= 228 ~ 6, # "16 a 19 anos",       
      idade2 > 228 & idade2 <= 468 ~ 7, # "20 a 39 anos",       
      idade2 > 468 & idade2 <= 708 ~ 8, # "40 a 59 anos",       
      idade2 > 708 & idade2 <= 840 ~ 9, # "60 a 70 anos",      
      idade2 > 840 ~ 10 # "71 anos e mais"
    ))
  
  dados$faixa_etaria <- as.integer(as.character(dados$faixa_etaria))
  dados$faixa_etaria[is.na(dados$faixa_etaria)] <- 99
  
  # Renomear categorias da variável qualAntiviral
  log_info('Renomeando categorias da variável qualAntiviral')
  
  dados <- dados |>
    mutate(qualAntiviral = case_when(
      qualAntiviral == "" ~ 0, #"Outro",
      qualAntiviral == "Outro" ~ 0, #"Outro",
      qualAntiviral == "Nirmatrevir/Ritonavir" ~ 1, #"Nirmatrevir/Ritonavir",
      qualAntiviral == "Normatrevir/Ritonavir" ~ 1, #"Nirmatrevir/Ritonavir"
      qualAntiviral == "Baricitinibe" ~ 2 #"Baricitinibe",
    ))
  
  dados$qualAntiviral = as.integer(as.numeric(dados$qualAntiviral))
  
  dados$qualAntiviral[is.na(dados$qualAntiviral)] <- 9
  
  # Ano e semana epidemiológica
  log_info('Criando variável semana epidemiológica')
  
  dados$semana_epi <- dados$semEpiSintomas
  dados$ano <- dados$anoEpiSintomas
  
  dados = transform(dados, ano_semepi = interaction(ano, semana_epi, sep = ""))
  
  dados <- dados |> 
    mutate(domingo = epiweek2date(anoEpiSintomas, semEpiSintomas),
           mes = month(domingo, label = TRUE, abbr = FALSE))
  
  # Vetor de referência com a ordem correta
  ordem_meses <- c("janeiro", "fevereiro", "março", "abril", "maio", "junho", 
                   "julho", "agosto", "setembro", "outubro", "novembro", "dezembro")
  
  # Usar match para encontrar a posição do nome do mês no vetor de ordem_meses
  # (A posição é o número do mês: 'janeiro' é o 1º, 'fevereiro' é o 2º, etc.)
  # Substitua 'nome_do_mes' pelo nome real da sua coluna
  dados$mes <- match(dados$mes, ordem_meses)
  
  
  # Criar variáveis grupos de risco e populações específicas
  
  # gestantes e puérperas
  log_info('Criando variável gestantes_e_puerperas')
  
  dados <- dados |>
    mutate(gestantes_e_puerperas = ifelse(
      
      str_detect(
        condicoes, regex(".*gestante|pu[eé]rpera.*", ignore_case = TRUE)) | codigoTriagemPopulacaoEspecifica == 3, 1, 0) # Gestantes e puÃ©rperas    
    )
  
  dados$gestantes_e_puerperas[is.na(dados$gestantes_e_puerperas)] <- 9
  
  # GRUPOS DE RISCO - IMUNOSSUPRIMIDOS
  
  # Não foi criada uma variável com o campo "gestante" porque já foi criada uma variável "gestante2"
  # que une dois campos com essa categoria.
  
  # Doenças respiratórias crônicas descompensadas
  log_info('Criando variável doencas_respisratorias_cronicas_descompensadas')
  
  dados <- dados |>
    mutate(doencas_respiratorias_cronicas_descompensadas = if_else(
      str_detect(
        condicoes, regex(
          #  ".*doencas respiratorias cronicas descompensadas.*",
          ".*respiratori.*cronic.*", ignore_case = TRUE)), "1", "0", NA_character_
    ))
  
  dados$doencas_respiratorias_cronicas_descompensadas[is.na(dados$doencas_respiratorias_cronicas_descompensadas)] <- 9
  
  
  # Doenças renais crônicas em estágio avançado
  log_info('Criando variável doencas_renais_cronicas_em_estagio_avancado')
  
  dados <- dados |>
    mutate(doencas_renais_cronicas_em_estagio_avancado = if_else(
      str_detect(
        condicoes, regex(
          #  ".*doencas renais cronicas em estagio avancado.*",
          ".*rena.*", ignore_case = TRUE)), "1", "0", NA_character_
    ))
  
  dados$doencas_renais_cronicas_em_estagio_avancado[is.na(dados$doencas_renais_cronicas_em_estagio_avancado)] <- 9
  
  
  # Portador de doenças cromossômicas ou estado de fragilidade imunológica
  log_info('Criando variável portador_de_doencas_cromossomicas_ou_estado_de_fragilidade_imunologica')
  
  dados <- dados |>
    mutate(portador_de_doencas_cromossomicas_ou_estado_de_fragilidade_imunologica = if_else(
      str_detect(
        condicoes, regex(
          #  ".*portador de doencas cromossomicas ou estado de fragilidade imunologica.*", 
          ".*cromossomic|fragilidade imunologi.*", ignore_case = TRUE)), 
      "1", "0", NA_character_
    ))
  
  dados$portador_de_doencas_cromossomicas_ou_estado_de_fragilidade_imunologica[is.na(dados$portador_de_doencas_cromossomicas_ou_estado_de_fragilidade_imunologica)] <- 9
  
  
  # Doenças cardíacas crônicas
  log_info('Criando variável doencas_cardiacas_cronicas')
  
  dados <- dados |>
    mutate(doencas_cardiacas_cronicas = if_else(
      str_detect(
        condicoes, regex(
          #  ".*doencas cardiacas cronicas.*", 
          ".*cardiac.*", ignore_case = TRUE)),
      "1", "0", NA_character_
    ))
  
  dados$doencas_cardiacas_cronicas[is.na(dados$doencas_cardiacas_cronicas)] <- 9
  
  
  # Imunossupressão
  log_info('Criando variável imunossupressao')
  
  dados <- dados |>
    mutate(imunossupressao = if_else(
      str_detect(
        condicoes, regex(
          #  ".*imunossupressao.*"
          ".*imunossupress.*", ignore_case = TRUE)),
      "1", "0", NA_character_
    ))
  
  dados$imunossupressao[is.na(dados$imunossupressao)] <- 9
  
  
  # Diabetes
  log_info('Criando variável diabetes')
  
  dados <- dados |>
    mutate(diabetes = if_else(
      str_detect(
        condicoes, regex(
          #  ".*diabetes.*"
          ".*diabete.*", ignore_case = TRUE)),
      "1", "0", NA_character_
    ))
  
  dados$diabetes[is.na(dados$diabetes)] <- 9
  
  # Obesidade
  log_info('Criando variável obesidade')
  
  dados <- dados |>
    mutate(obesidade = if_else(
      str_detect(
        condicoes, regex(".*obesidade.*", ignore_case = TRUE)),
      "1", "0", NA_character_
    ))
  
  dados$obesidade[is.na(dados$obesidade)] <- 9
  
  
  ##################################################
  
  # TRIAGEM POPULAÇÃO ESPECÍFICA
  log_info('Criando variável trabalhadores_de_servicos_essenciais_ou_estrategicos')
  
  dados <- dados |>
    mutate(trabalhadores_de_servicos_essenciais_ou_estrategicos = if_else(
      codigoTriagemPopulacaoEspecifica == 1,  
      "1", "0", NA_character_
    ))
  
  dados$trabalhadores_de_servicos_essenciais_ou_estrategicos <- as.integer(dados$trabalhadores_de_servicos_essenciais_ou_estrategicos)
  
  dados$trabalhadores_de_servicos_essenciais_ou_estrategicos[is.na(dados$trabalhadores_de_servicos_essenciais_ou_estrategicos)] <- 9
  
  # Profisisonais de saúde
  log_info('Criando variável profissionais_de_saude')
  
  dados <- dados |>
    mutate(profissionais_de_saude = ifelse(
      codigoTriagemPopulacaoEspecifica == 2 |
        profissionalSaude == 1, 1, 0)
    )
  
  dados$profissionais_de_saude[is.na(dados$profissionais_de_saude)] <- 9
  
  
  # Povos e comunidades tradicionais
  log_info('Criando variável povos_e_comunidades_tradicionais')
  
  dados <- dados |>
    mutate(povos_e_comunidades_tradicionais = if_else(
      codigoTriagemPopulacaoEspecifica == 4,      
      "1", "0", NA_character_
    ))
  
  dados$povos_e_comunidades_tradicionais <- as.integer(dados$povos_e_comunidades_tradicionais)
  
  dados$povos_e_comunidades_tradicionais[is.na(dados$povos_e_comunidades_tradicionais)] <- 9
  
  # Outros
  log_info('Criando variável outros_popespecif')
  
  dados <- dados |>
    mutate(outros_popespecif = if_else(
      codigoTriagemPopulacaoEspecifica == 5,      
      "1", "0", NA_character_
    ))
  
  dados$outros_popespecif <- as.integer(dados$outros_popespecif)
  
  dados$outros_popespecif[is.na(dados$outros_popespecif)] <- 9
  
  
  # Ajustar código de municípios
  log_info('Ajustando códigos dos municípios')
  
  dados <- dados |> mutate(municipioIBGE = substr(municipioIBGE, 1, 6))
  
  dados$municipioIBGE[is.na(dados$municipioIBGE)] <- 999999
  
  dados$municipioIBGE <- as.integer(dados$municipioIBGE)
  
  
  # Transformar valores NA em valores
  log_info('Codificando valores "NA" em 9/99')
  
  dados$codigoQualAntiviral[is.na(dados$codigoQualAntiviral)] <- 9
  
  dados$comunidadeTradicional[is.na(dados$comunidadeTradicional)] <- 99
  
  
  # Selecionar variáveis
  log_info('Selecionando variáveis para o data.frame final')
  
  dados <- dados[, c(
    "comunidadeTradicional",
    "evolucaoCaso",
    "dataInicioSintomas",
    "classificacaoFinal",
    "municipioIBGE",
    "estadoIBGE",
    "estadoNotificacao",
    "idade",
    "sexo",
    "racaCor",
    "qualAntiviral",
    "caso_novo",
    "faixa_etaria",
    "semana_epi",
    "mes",
    "ano",
    "ano_semepi",
    "gestantes_e_puerperas",
    "doencas_respiratorias_cronicas_descompensadas",
    "doencas_renais_cronicas_em_estagio_avancado",
    "portador_de_doencas_cromossomicas_ou_estado_de_fragilidade_imunologica",
    "doencas_cardiacas_cronicas",
    "imunossupressao",
    "diabetes",
    "obesidade",
    "trabalhadores_de_servicos_essenciais_ou_estrategicos",
    "profissionais_de_saude",
    "povos_e_comunidades_tradicionais",
    "outros_popespecif",
    "codigoQualAntiviral"
  )]
  
  
  # Filtrar dados por ano
  log_info('Filtrando dados por ano')
  dados = dados |>
    dplyr::filter(ano %in% c(2023, 2024, 2025))
  
  log_info('Filtrando apenas os casos novos')
  dados <- dados |>
    dplyr::filter(caso_novo == 1)
  
  log_success('Tratamento de dados finalizado!')
}
