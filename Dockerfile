FROM rocker/shiny:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libmariadb-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c('shiny', 'DBI', 'RMariaDB', 'aws.s3', 'aws.signature'), repos='https://cran.rstudio.com/')"

# Create app directory
RUN mkdir -p /srv/shiny-server/myapp

# Copy the app to the image
COPY app.R /srv/shiny-server/myapp/
COPY rds_s3_config.R /srv/shiny-server/myapp/

# Set permissions
RUN chown -R shiny:shiny /srv/shiny-server/

# Expose port
EXPOSE 3838

# Run the app
CMD ["/usr/bin/shiny-server"]