#######################
# Executar o pipeline #
#######################

library(logger)

# Diretório de destino dos arquivos de logs
log_dir <- "./data/logs/" 

# Configuração do appender
log_appender(
  appender_file(file.path(log_dir, paste0("log_", Sys.Date(), ".log"))), 
  index = 2
)

# Configuração para um layout de logs limpo
meu_layout_limpo <- layout_glue_generator(
  format = "{level} [{time}] {msg}"
)

log_layout(meu_layout_limpo, index = 2)

log_info("Iniciando pipeline de ETL - Tarefa: SharePoint Sync")

# Pacote externo (não está no CRAN) criado pelo Marcelo (CGCOVID)
source('./utils/episem.R')
source('./src/extract_data.R')
source('./src/data_process.R')
source('./src/load_data.R')

executar_pipeline <- function() {
  tryCatch({
    log_info('Iniciando pipeline...')
    # Configurações
    config <- yaml.load_file('.config/config.yml')
    
    # Paths
    PATH_EPISEM <- config$paths$path_cgcovid_package
    PATH_INPUT <- config$paths$path_data
    PATH_OUTPUT <- config$paths$path_output
    
    # Extrair dados do Sharepoint
    log_info('Download do arquivo parquet')
    baixar_parquet_sharepoint()
    
    # Importar dados
    log_info('Importar dados do parquet')
    dados <- read_parquet(PATH_INPUT)
    
    # Processamento de dados
    log_info('Realizar tratamento de dados')
    dados <- tratamento_de_dados(dados)
    
    # Salvar dados em arquivo CSV
    log_info('Exportar dados tratados')
    write_delim(dados, PATH_OUTPUT, delim = ";")
    
    # Upload de dados
    log_info('Carregar arquivo de dados no Sharepoint.')
    upload_arquivo_csv()
    
    log_success('Pipeline executado com sucesso!')
  }, error = function(e) {
    log_fatal('Falha na execução do pipeline: {e$message}')
  })
}

executar_pipeline()
