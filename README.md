# Hello World project by Andrea Arduino
## Software requirements
In order to successfully deploy the Hello World project please make sure to satisfy the following requirements:
1. have a **Linux-based** working station
2. install [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-linux.html) on your working station
3. have **administrative access** to an AWS Account
4. create an **AWS IAM User** with the following properties:
   * **administrative privileges** - attach AWS IAM Policy named *AdministratorAccess*
   * **programmatic access enabled** - make sure to store *Access Key ID* and *Secret Access Key* at IAM User creation time

*Please note that if you already have an AWS IAM User with the required properties you can skip point 4 of the list above.*

## How to deploy the Hello World project
Follow the instructions below in order to deploy the project:
1. **Clone** the [repository](https://github.com/AndreaArduino/arduino-hello-world)
```
git clone https://github.com/AndreaArduino/arduino-hello-world.git
```
2. **Run the Bash script** named [create_project.sh](scripts/create_project.sh) stored under *script* folder in the repository:
```
bash <path/to/repo>/scripts/create_project.sh
```
3. The script will do the following:
   * **ask the user** to enter *Access Key ID* and *Secret Access Key* of the IAM User created at point 4 of the *Software Requirements* section
   * **create a local profile** with the credentials provided by the user - it will be used for all the subsequent requests to AWS made by AWS CLI
   * **create AWS CloudFormation Stack** which handles the *network layer* of the AWS infrastructure - AWS VPC, AWS Internet Gateway, Subnets, Route Tables, AWS NAT Gateway
   * **import self-signed SSL certificate** to AWS ACM
   * **check and - if needed - create an AWS ECS service-linked IAM Role** - needed by AWS ECS Service to interact with AWS ELB
   * **create AWS CloudFormation Stack** which handles the *application components* - I will describe those components later on in this document.
   * **return the public url** of the Hello World application

## Hello World project description

In this section I will explain the repository structure - for your convenience - and the high level infrastructure of the application.

### Repository structure
* **cloudformation**: contains the **AWS CloudFormation templates** in JSON format as well as the source Python code - [Troposphere library](https://troposphere.readthedocs.io/en/latest/) - from which they are generated.
  * **vpc.(json|py)**: network layer
  * **infra.(json|py)**: application layer
* **docker**:
  * **hello-world**: contains **UWSGI application server** [configuration file](docker/hello-world/uwsgi_conf/hello-world.ini) and [Dockerfile](docker/hello-world/Dockerfile) for the application server Docker container
  * **nginx**: contains **Nginx web server** [configuration file](docker/nginx/conf/hello-world.conf) and the [Dockerfile](docker/nginx/Dockerfile) for the web server Docker container
* **hello-world**: contains the [application code](hello-world/hello-world.py) developed in Python
* **scripts**: contains the [create_project.sh](scripts/create_project.sh) script which handles the deployment of the project on AWS as described in the previous section.
* **ssl**: contains [public](ssl/arduino-hello-world-com.crt) and [private](ssl/arduino-hello-world-com.key) key of a self signed SSL certificate.

### High level infrastructure
* **AWS Application Load Balancer**:
  * acts as the *public entrypoint* for the application
  * serves traffic via *HTTP and HTTPS protocols*
  * exposes a *self-signed SSL certificate*
  * implements *redirect* - HTTP to HTTPS
  * forwards traffic to AWS ECS Fargate Task running the application - SSL off-loading is implemented.
* **AWS Elastic Container Service**:
  * includes a *Cluster* controlled by a *Service* which always maintains a single *Fargate Task* up&running
  * **ECS Fargate Task** properties:
    * deployed in a *private subnet*. It can reach the public Internet through AWS NAT Gateway
    * it is attached to the AWS Application Load Balancer through the *AWS ECS Service*
    * can receive traffic from AWS Application Load Balancer *only*
    * runs two Docker containers:
      * one for the *Nginx web server* listening on port 80
      * one for the *UWSGI application server* listening on port 8080 and running the Python application

### Hello World project design approach

I have designed the AWS infrastructure following the [AWS Well Architected Framework](https://aws.amazon.com/architecture/well-architected/?nc1=h_ls) principles - which defines AWS best practices in terms of security, performances, operational efficiency, costs and reliability - with a focus on security, reliability and operational efficiency:
* **security**: the application runs in a **private subnets** not reachable from the public Internet. The only way to access it is from the AWS ELB. I have **hardened the Nginx web server** configuration - eliminating server tokens, enabling XSS protection header and disabled unnecessary methods. I will also explain how security may be improved for a deployment in Production environment - see [ANSWERS.md](ANSWERS.md).
* **reliability**: the AWS ECS Service automatically replace the AWS ECS Fargate Task in case of any failure - e.g. if a Docker container stops working. I will explain how reliability may be improved for a deployment in Production environment - see [ANSWERS.md](ANSWERS.md).
* **operational efficiency**: the application runs in a serverless infrastructure - eliminating the overhead of AWS EC2 OS management
* **performances**: I have not considered performances during the design because it is a sample application. I will explain how this aspect may be improved for a deployment in Production environment - see [ANSWERS.md](ANSWERS.md).
* **costs**: I have not considered costs during the design because it is a sample application.

Other considerations:
* I have exploited **Docker containers** to run the application because they can be easily *replicated* and *ported* in different environments
* I have adopted **AWS Application Load Balancer** because it allows to easily and safely forward traffic to **AWS ECS Fargate Tasks**. It can also implement **redirects** - e.g. HTTP to HTTPS.
* I have not adopted AWS EKS as a Docker orchestration tool because I have no experience with it - this is why I have chosen AWS ECS which on the other hand is a very stable and powerful AWS service designed for Docker orchestration.
* I have adopted Nginx as a web server solution as it performs optimally when associated with UWSGI application server.
* I have exploited AWS CloudFormation in order to deploy the AWS infrastructure with an *infrastructure-as-a-code* approach.
