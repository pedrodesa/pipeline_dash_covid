# Instalar pacotes
pacotes <- c(
  "dplyr",
  "readr",
  "purrr",
  "lubridate",
  "arrow",
  "stringr",
  "testthat",
  "devtools",
  "arrow",
  "yaml",
  "dotenv",
  "httr",      # Sharepoint extract
  "jsonlite",   # Sharepoint extract
  "fs",          # Manipulação de arquivos e pastas
  "logger"        # Logs da aplicação
)

if (sum(as.numeric(!pacotes %in% installed.packages())) != 0) {
  instalador <- pacotes[!pacotes %in% installed.packages()]
  for (i in 1:length(instalador)) {
    install.packages(instalador, dependencies = T)
    break()
  }
  sapply(pacotes, require, character = T)
} else {
  sapply(pacotes, require, character = T)
}
