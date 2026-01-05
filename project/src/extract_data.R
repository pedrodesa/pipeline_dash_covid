# ==== Função para importar arquivo de dados do Sharepoint ==== #
baixar_parquet_sharepoint <- function(
    config_path = "./config/config.yml",
    destino_local = "./data/raw"
) {
  require(httr)
  require(jsonlite)
  require(yaml)
  require(logger)
  
  log_info('Iniciando etapa de extração de dados do Sharepoint...')
  
  # === 1. CARREGAR CONFIG ===
  config <- yaml.load_file(config_path)
  
  tenant_id <- Sys.getenv("TENANT_ID")
  client_id <- Sys.getenv("CLIENT_ID")
  client_secret <- Sys.getenv("CLIENT_SECRET")
  
  scope <- "https://graph.microsoft.com/.default"
  token_url <- paste0("https://login.microsoftonline.com/", tenant_id, "/oauth2/v2.0/token")
  
  # === 2. OBTER TOKEN ===
  log_info('Obtendo Token de acesso')
  
  token_resp <- POST(
    url = token_url,
    body = list(
      grant_type = "client_credentials",
      client_id = client_id,
      client_secret = client_secret,
      scope = scope
    ),
    encode = "form"
  )
  
  token <- content(token_resp)$access_token
  
  if (is.null(token)) {
    log_info('Erro ao obter o token de autenticação!')
    stop('Processo finalizado com erro!')
  }
  
  # === 3. DESCOBRIR site_id ===
  log_info('Obtendo site_id...')
  
  site_name <- config$sharepoint$site_name
  site_query <- URLencode(site_name, reserved = TRUE)
  
  site_resp <- GET(
    paste0("https://graph.microsoft.com/v1.0/sites?search=", site_query),
    add_headers(Authorization = paste("Bearer", token))
  )
  
  if (status_code(site_resp) != 200) {
    log_info('Resposta diferente de 200/201: {content(site_resp)}')
    stop("Erro ao localizar o site no SharePoint!")
  }
  
  site_info <- content(site_resp, as = "parsed")
  site_id <- site_info$value[[1]]$id
  
  log_info('site_id encontrado: {site_id}')
  
  # === 4. OBTER drive_id ===
  log_info('Obtendo drive_id...')
  site_id_enc <- URLencode(site_id, reserved = TRUE)
  
  drive_resp <- GET(
    paste0("https://graph.microsoft.com/v1.0/sites/", site_id_enc, "/drives"),
    add_headers(Authorization = paste("Bearer", token))
  )
  
  if (status_code(drive_resp) != 200) {
    log_info('Resposta diferente de 200/201: {content(drive_resp)}')
    stop("Erro ao obter drives do site!")
  }
  
  drive_info <- content(drive_resp, as = "parsed")
  drive_id <- drive_info$value[[1]]$id
  
  log_info('drive_id encontrado: {drive_id}')
  
  # === 5. DOWNLOAD DO ARQUIVO ===
  log_info('Iniciando download do arquivo...')
  
  file_path <- config$sharepoint$caminho_input
  
  file_url <- paste0(
    "https://graph.microsoft.com/v1.0/sites/", site_id_enc,
    "/drives/", drive_id,
    "/root:/", URLencode(file_path, reserved = TRUE),
    ":/content"
  )
  
  if (!dir.exists(destino_local)) dir.create(destino_local, recursive = TRUE)
  local_file <- file.path(destino_local, basename(file_path))
  
  download_resp <- GET(
    file_url,
    add_headers(Authorization = paste("Bearer", token)),
    write_disk(local_file, overwrite = TRUE)
  )
  
  if (status_code(download_resp) != 200) {
    log_info('Resposta diferente de 200/201: {local_file}')
    stop("Falha ao baixar o arquivo parquet!")
  }
  
  # === 6. RETORNO DA FUNÇÃO ===
  return(local_file)
}
