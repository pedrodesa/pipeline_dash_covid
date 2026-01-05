upload_arquivo_csv <- function() {
  require(httr)
  require(jsonlite)
  require(yaml)
  require(fs)
  
  # Configurações ----
  config <- yaml::read_yaml('./config/config.yml')
  
  TENANT_ID <- Sys.getenv('TENANT_ID')
  CLIENT_ID <- Sys.getenv('CLIENT_ID')
  CLIENT_SECRET <- Sys.getenv('CLIENT_SECRET')
  
  # Parâmetros de arquivo e sharepoint
  LOCAL_DIR <- config$sharepoint_output$pasta_arquivo_output     # caminho local completo
  REMOTE_PATH <- config$sharepoint_output$caminho_output         # pasta do SharePoint
  NOME_ARQUIVO <- config$sharepoint_output$nome_arquivo_output   # nome final no SharePoint
  SITE_NAME <- config$sharepoint_output$site_name_output
  
  # Configurações de API
  GRAPH_URL <- 'https://graph.microsoft.com/v1.0'
  SCOPE <- 'https://graph.microsoft.com/.default'
  TOKEN_URL <- paste0('https://login.microsoftonline.com/', TENANT_ID, '/oauth2/v2.0/token')
  
  # Funções de tratamento de Erros ----
  check_response_status <- function(resp, error_message = 'Erro na requisição da API!') {
    if (httr::status_code(resp) >= 400) {
      message(error_message)
      # Tenta extrair a mensagem de erro do Graph API
      error_content <- tryCatch(
        httr::content(resp, as = 'parsed', encoding = 'UTF-8'),
        error = function(e) httr::content(resp, 'text')
      )
      stop(paste0(error_message, ': ', jsonlite::toJSON(error_content, auto_unbox = TRUE, pretty = TRUE)))
    }
  }
  
  # Autenticação ----
  log_info('Iniciando a autenticação...')
  
  token_resp <- POST(
    TOKEN_URL,
    body = list(
      grant_type = 'client_credentials',
      client_id = CLIENT_ID,
      client_secret = CLIENT_SECRET,
      scope = SCOPE
    ),
    encode = 'form'
  )
  
  check_response_status(token_resp, 'Erro ao obter token de acesso')
  ACCESS_TOKEN <- httr::content(token_resp)$access_token
  log_info('Autenticação bem sucedida!')
  
  # Obter ID do site (site_id) ----
  
  # O endpoint 'sites?search=' é lento. A melhor prática é usar '/sites/{hostname}:/{site-path}' se possível.
  # Para a busca por nome:
  site_query_encoded <- URLencode(SITE_NAME, reserved = TRUE)
  site_search_url <- paste0(GRAPH_URL, '/sites?search=', site_query_encoded)
  
  log_info('Buscando site ID...')
  
  site_resp <- GET(
    site_search_url,
    add_headers(Authorization = paste('Bearer', ACCESS_TOKEN))
  )
  
  check_response_status(site_resp, 'Erro ao buscar o site')
  
  site_data <- httr::content(site_resp, as = 'parsed', simplifyVector = TRUE)
  
  if (length(site_data$value) == 0) {
    log_info('Erro ao buscar o site')
    stop(paste('Nenhum site encontrado com o nome: ', SITE_NAME))
  }
  
  SITE_ID <- site_data$value$id[1]
  log_info('Site encontrado: {SITE_ID}')
  
  # Obter ID do drive padrão (drive_id) ----
  
  # O drive padrão é geralmente o "Shared Documents".
  drive_url <- paste0(GRAPH_URL, '/sites/', SITE_ID, '/drives')
  
  log_info('Buscando drive ID...')
  
  drive_resp <- GET(
    drive_url,
    add_headers(Authorization = paste('Bearer', ACCESS_TOKEN))
  )
  
  check_response_status(drive_resp, 'Erro ao obter drives')
  
  drive_data <- httr::content(drive_resp, as = "parsed", simplifyVector = TRUE)
  DRIVE_ID <- drive_data$value$id[1]
  log_info('Drive encontrado: {DRIVE_ID}')
  
  # Preparar e iniciar upload session ----
  
  # Path completo no SharePoint para o arquivo (pasta + nome do arquivo)
  remote_file_path <- paste0(REMOTE_PATH, '/', NOME_ARQUIVO)
  
  # Endpoint para criar a sessão de upload
  upload_session_url <- paste0(
    GRAPH_URL, '/drives/', DRIVE_ID,
    '/root:/', URLencode(remote_file_path, reserved = TRUE),
    ':/createUploadSession'
  )
  
  log_info('Criando Upload Session...')
  
  # Cria a sessão com a instrução de substituir (replace) se o arquivo existir
  session_resp <- POST(
    upload_session_url,
    add_headers(
      Authorization = paste('Bearer', ACCESS_TOKEN),
      "Content-Type" = "application/json"
    ),
    body = list(
      item = list(
        "@microsoft.graph.conflictBehavior" = "replace"
      )
    ),
    encode = "json"
  )
  
  check_response_status(session_resp, "Erro ao criar upload session")
  
  UPLOAD_URL <- content(session_resp)$uploadUrl
  log_info('Upload session criada!')
  
  # Fazer upload do arquivo em chunks ----
  FILE_SIZE <- fs::file_size(LOCAL_DIR)
  CHUNK_SIZE <- 1024 * 1024 * 10 # 10MB
  
  conn <- file(LOCAL_DIR, 'rb')
  START_BYTE <- 0
  log_info(paste('Iniciando upload de:', format(FILE_SIZE, big.mark = ".", scientific = FALSE), 'bytes...'))
  
  repeat {
    chunk <- readBin(conn, what = 'raw', n = CHUNK_SIZE)
    
    if (length(chunk) == 0) break # Sai do loop quando o arquivo termina
    
    END_BYTE <- START_BYTE + length(chunk) - 1
    
    log_info(sprintf(' → Enviando chunk %d-%d de %d bytes...',
                     START_BYTE,
                     END_BYTE,
                     FILE_SIZE))
    
    # A requisição PUT do chunk
    resp <- PUT(
      UPLOAD_URL,
      add_headers(
        'Content-Type' = 'application/octet-stream',
        # O Content-Range é **crítico**
        'Content-Range' = sprintf('bytes %d-%d/%d', START_BYTE, END_BYTE, FILE_SIZE)
      ),
      body = chunk
    )
    
    # Tratamento de erro específico para o chunk
    if (status_code(resp) >= 400) {
      log_info("Erro no envio do chunk:")
      print(content(resp))
      close(conn)
      stop('Erro durante upload do chunk. Sessão cancelada.')
    }
    
    # Atualiza o ponto de partida para o próximo chunk
    START_BYTE <- END_BYTE + 1
  }
  
  close(conn)
  
  log_info('Upload finalizado!')
  
  # O último `resp` contém os metadados do arquivo completo
  final_content <- content(resp, as = "parsed")
  
  if ("id" %in% names(final_content)) {
    log_success('Arquivo enviado com sucesso. ID do Item: {final_content$id}')
  } else {
    log_fatal("Resposta final não contém o ID do item. Verifique o log acima.")
  }
}
