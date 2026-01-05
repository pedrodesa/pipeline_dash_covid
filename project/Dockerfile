FROM rocker/r-base:latest

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libpq-dev \
    libgit2-dev \
    && rm -rf /var/lib/apt/lists/*

# Diretório de trabalho
WORKDIR /app

# Copiar apenas o script de instalação de pacotes
COPY install_packages.R /app/install_packages.R

# Instalar pacotes R
RUN Rscript install_packages.R

# Copiar o projeto
COPY . .

# Rodar a aplicação principal
CMD ["Rscript", "main.R"]
