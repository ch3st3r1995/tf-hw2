terraform {
  required_version = "1.4.5" #major part, minor part, patch
  backend "s3" {
    region  = "us-east-1"                         #region where your bucket located
    profile = "default"                           #name of your bucket
    key     = "batch-8-second-lesson-state-file" #name of your state file
    bucket  = "batch8-backend2"                   #bucket name where you store your state file
    
  }
}
