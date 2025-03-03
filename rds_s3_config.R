# AWS RDS Configuration 
# Reads from environment variables first, falls back to defaults for development
rds_config <- list(
  host = Sys.getenv("RDS_HOST", "your_database_endpoint"),
  port = as.numeric(Sys.getenv("RDS_PORT", "3306")),
  dbname = Sys.getenv("RDS_DBNAME", "shiny_random_data"),
  username = Sys.getenv("RDS_USERNAME", "admin"),
  password = Sys.getenv("RDS_PASSWORD", "db_password")
)

# AWS S3 Configuration
# Reads from environment variables first, falls back to defaults for development
s3_config <- list(
  access_key = Sys.getenv("AWS_ACCESS_KEY", "your_aws_access_key"),
  secret_key = Sys.getenv("AWS_SECRET_KEY", "your_aws_screct_key"),
  region = Sys.getenv("AWS_REGION", "eu-north-1"),
  bucket = Sys.getenv("S3_BUCKET", "sirpi-shear-test")
)

# Function to validate configurations
validate_configs <- function() {
  # Check RDS config
  if(rds_config$host == "your_database_endpoint") {
    warning("Using default RDS host. Set RDS_HOST environment variable in production.")
  }
  
  # Check S3 config
  if(s3_config$access_key == "your_aws_access_key" || s3_config$secret_key == "your_aws_screct_key") {
    warning("Using default AWS credentials. Set AWS_ACCESS_KEY and AWS_SECRET_KEY environment variables in production.")
  }
  
  if(s3_config$bucket == "sirpi-shear-test") {
    warning("Using default S3 bucket name. Set S3_BUCKET environment variable in production.")
  }
}

# Run validation on startup (comment out in production if not needed)
validate_configs()