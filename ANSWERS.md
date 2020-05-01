1. Time of completion: **2 days**
2. Improvements:
   * **Logging** configuration at all levels - AWS VPC FlowLogs, AWS ELB, AWS ECS Fargate Task, Docker containers (both Nginx and UWSGI)
   * **Docker containers**: split web server and application server Docker images in two layers
     * a **base image** with packages installation - Nginx for web server, uwsgi for application server
     * a **second image built on top of the base one** for web/application server configuration files deployment.
   * Follow least privilege approach for IAM User adopted for AWS resources creation.
3. Improvements for a production-ready environment:
   * **security**:
     * Exploit AWS Web Application Firewall
     * Public CA-signed SSL certificate - need to register domain on DNS provider as AWS Route53 in order to validate the SSL certificate. The SSL certificate may be provided by AWS ACM.
   * **reliability**:
     * deploy at least two AWS ECS Fargate Tasks in two different AWS Availability Zones
   * **operational efficiency**:
     * **CI/CD** implementation for Nginx configuration, UWSGI configuration and application code deployment exploiting AWS CodePipeline as the pipeline orchestrator, AWS CodeBuild for Docker images build, AWS Code Deploy for Docker containers deployment on AWS
     * **AWS CloudTrail** in order to keep trace of all actions performed on the AWS account
     * **AWS Config** to record the infrastructure configuration changes over time
     * **Monitoring**: AWS CloudWatch to monitor AWS ELB metrics - e.g. latency, error
   * **performances**:
     * **AWS ECS Fargate Tasks autoscaling** - scale out based off key metrics like CPU usage, AWS ELB latency, etc
     * **AWS CloudFront** to leverage caching and reduce latency and the amount of requests towards the origin
4. I have chosen Python as it is a programming language which I have widely used in previous projects.
5. The biggest challenge has been to respect the deadline because I have implemented an "almost-production-ready" solution in a relatively short amount of time.
