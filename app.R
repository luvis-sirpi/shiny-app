library(shiny)
library(DBI)
library(RMariaDB)
library(aws.s3)

# Source configuration file
source("rds_s3_config.R")

ui <- fluidPage(
  titlePanel("Sample Shiny App with AWS Integration"),
 
  sidebarLayout(
    sidebarPanel(
      numericInput("num", "Number of Random Samples:", 100, min = 10, max = 1000),
      actionButton("generate", "Generate Data"),
      actionButton("saveToRDS", "Save to RDS Database"),
      actionButton("saveToS3", "Save to S3 Bucket"),
      downloadButton("downloadData", "Download CSV")
    ),
   
    mainPanel(
      plotOutput("histPlot"),
      verbatimTextOutput("summary"),
      verbatimTextOutput("awsStatus")
    )
  )
)

server <- function(input, output, session) {
  # Reactive dataset and session ID
  data <- reactiveVal()
  sessionID <- reactiveVal(paste0("session_", format(Sys.time(), "%Y%m%d%H%M%S"), "_", sample(1000:9999, 1)))
  statusMsg <- reactiveVal("")
  
  # Initialize server
  observe({
    # Check if database exists and create if needed
    tryCatch({
      # Connect to RDS (to the MySQL server, not to a specific database)
      con <- dbConnect(
        drv = RMariaDB::MariaDB(),
        host = rds_config$host,
        port = rds_config$port,
        user = rds_config$username,
        password = rds_config$password
      )
      
      # Check if our database exists
      databases <- dbGetQuery(con, "SHOW DATABASES")
      if(!rds_config$dbname %in% databases$Database) {
        # Create the database if it doesn't exist
        dbExecute(con, paste0("CREATE DATABASE ", rds_config$dbname))
        statusMsg(paste0("Created database: ", rds_config$dbname))
      }
      
      # Switch to our database
      dbExecute(con, paste0("USE ", rds_config$dbname))
      
      # Check if our table exists
      tables <- dbGetQuery(con, "SHOW TABLES")
      if(nrow(tables) == 0 || !"sample_data" %in% tables[[1]]) {
        # Create the table if it doesn't exist
        dbExecute(con, "
          CREATE TABLE sample_data (
            id INT AUTO_INCREMENT PRIMARY KEY,
            session_id VARCHAR(255) NOT NULL,
            timestamp DATETIME NOT NULL,
            value FLOAT NOT NULL
          )
        ")
        statusMsg(paste0("Created table: sample_data in database ", rds_config$dbname))
      } else {
        statusMsg("Connected to RDS successfully. Database and table exist.")
      }
      
      # Close connection
      dbDisconnect(con)
    }, error = function(e) {
      statusMsg(paste("Error connecting to RDS:", e$message))
    })
  })
  
  observeEvent(input$generate, {
    new_data <- rnorm(input$num, mean = 50, sd = 10)
    data(new_data)
    statusMsg("Data generated successfully")
  })
 
  # Save to RDS database
  observeEvent(input$saveToRDS, {
    req(data())
    
    tryCatch({
      # Create a dataframe with session information
      df <- data.frame(
        session_id = sessionID(),
        timestamp = Sys.time(),
        value = data()
      )
      
      # Connect to RDS
      con <- dbConnect(
        drv = RMariaDB::MariaDB(),
        host = rds_config$host,
        port = rds_config$port,
        dbname = rds_config$dbname,
        user = rds_config$username,
        password = rds_config$password
      )
      
      # Write data to database
      dbWriteTable(con, "sample_data", df, append = TRUE, row.names = FALSE)
      
      # Close connection
      dbDisconnect(con)
      
      statusMsg("Data saved to RDS successfully")
    }, error = function(e) {
      statusMsg(paste("Error saving to RDS:", e$message))
    })
  })
  
  # Save to S3 bucket
  observeEvent(input$saveToS3, {
    req(data())
    
    tryCatch({
      # Create a temporary CSV file
      temp_file <- tempfile(fileext = ".csv")
      df <- data.frame(value = data())
      write.csv(df, temp_file, row.names = FALSE)
      
      # Set AWS credentials
      Sys.setenv(
        "AWS_ACCESS_KEY_ID" = s3_config$access_key,
        "AWS_SECRET_ACCESS_KEY" = s3_config$secret_key,
        "AWS_DEFAULT_REGION" = s3_config$region
      )
      
      # Upload to S3
      s3_file_path <- paste0(sessionID(), "_data.csv")
      put_object(
        file = temp_file,
        object = s3_file_path, 
        bucket = s3_config$bucket
      )
      
      # Remove temp file
      unlink(temp_file)
      
      statusMsg(paste("Data saved to S3 bucket:", s3_config$bucket, "/", s3_file_path))
    }, error = function(e) {
      statusMsg(paste("Error saving to S3:", e$message))
    })
  })
 
  # Histogram plot
  output$histPlot <- renderPlot({
    req(data())  # Ensure data is available
    hist(data(), col = "steelblue", border = "white", main = "Histogram", xlab = "Value")
  })
 
  # Summary statistics
  output$summary <- renderPrint({
    req(data())
    summary(data())
  })
  
  # AWS operation status
  output$awsStatus <- renderText({
    statusMsg()
  })
 
  # Download CSV
  output$downloadData <- downloadHandler(
    filename = function() { paste0(sessionID(), "_data.csv") },
    content = function(file) {
      write.csv(data.frame(value = data()), file, row.names = FALSE)
    }
  )
}

shinyApp(ui, server)