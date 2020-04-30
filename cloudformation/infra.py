from os import path
from troposphere import AWS_REGION, Join, Parameter, Ref, Template, GetAtt, Tags, ImportValue
from troposphere.route53 import AliasTarget, RecordSet, RecordSetGroup
from troposphere.ec2 import SecurityGroup, SecurityGroupIngress
from troposphere.elasticloadbalancingv2 import LoadBalancer as AppLoadBalancer, TargetGroup, Listener as AppListener, TargetGroupAttribute, Action, Certificate
from troposphere.ecs import DeploymentConfiguration, LoadBalancer, Service, Cluster, TaskDefinition, ContainerDefinition, PortMapping, NetworkConfiguration, AwsvpcConfiguration
from troposphere.iam import Role, User

### Template Definition ###

template = Template()
template.description = "Hello world project VPC"

resources = {}

### Template Parameters ###

parameters = {}

parameters[ "Project" ] = template.add_parameter(Parameter(
    "Project",
    Type="String",
    Description="Project Name",
    Default="hello-world"))

parameters[ "Route53HostedZoneID" ] = template.add_parameter(Parameter(
    "Route53HostedZoneID",
    ConstraintDescription = "Existing hosted zone ID",
    Description = "Hosted Zone ID",
    Default = "",
    Type = "AWS::Route53::HostedZone::Id"))

### Security Groups ###

resources["ALBSecurityGroup"] = template.add_resource(SecurityGroup(
    "ALBSecurityGroup",
    GroupDescription = Join("-", [ Ref(parameters[ "Project" ]), "alb", "sg" ]),
    Tags = [ { "Key": "Name", "Value": Join("-", [ Ref(parameters[ "Project" ]), "alb", "sg" ]) },
             { "Key": "Project", "Value": Ref(parameters[ "Project" ]) } ],
    VpcId = ImportValue("VPC")
    ))

resources[ "ALBSgRuleHTTP" ] = template.add_resource(SecurityGroupIngress(
    "ALBSgRuleHTTP",
    DependsOn = [ resource for resource in [ "ALBSecurityGroup" ] ],
    CidrIp = "0.0.0.0/0",
    GroupId = Ref(resources[ "ALBSecurityGroup" ]),
    IpProtocol = "tcp",
    FromPort = 80,
    ToPort = 80
    ))

resources[ "ALBSgRuleHTTPS" ] = template.add_resource(SecurityGroupIngress(
    "ALBSgRuleHTTPS",
    DependsOn = [ resource for resource in [ "ALBSecurityGroup" ] ],
    CidrIp = "0.0.0.0/0",
    GroupId = Ref(resources[ "ALBSecurityGroup" ]),
    IpProtocol = "tcp",
    FromPort = 443,
    ToPort = 443
    ))

resources["HelloWorldECSTaskSecurityGroup"] = template.add_resource(SecurityGroup(
    "HelloWorldECSTaskSecurityGroup",
    GroupDescription = Join("-", [ Ref(parameters[ "Project" ]), "fargate", "sg" ]),
    Tags = [ { "Key": "Name", "Value": Join("-", [ Ref(parameters[ "Project" ]), "fargate", "sg" ]) },
             { "Key": "Project", "Value": Ref(parameters[ "Project" ]) } ],
    VpcId = ImportValue("VPC")
    ))

resources[ "ECSTaskRuleHTTP" ] = template.add_resource(SecurityGroupIngress(
    "ECSTaskRuleHTTP",
    DependsOn = [ resource for resource in [ "HelloWorldECSTaskSecurityGroup" ] ],
    GroupId = Ref(resources[ "HelloWorldECSTaskSecurityGroup" ]),
    SourceSecurityGroupId = Ref(resources[ "ALBSecurityGroup" ]),
    IpProtocol = "tcp",
    FromPort = 80,
    ToPort = 80
    ))

### Application Load Balancer SSL Certificate ###

'''
parameters["SSLCertificateALB"] = template.add_parameter(Parameter(
    "SSLCertificateELB",
    ConstraintDescription = "SSL Certificate ARN",
    Description = "SSL certificate ARN for ALB",
    Default = "arn:aws:acm:eu-west-1:007023067155:certificate/8827afe7-02a8-4464-94de-902dde8171e0",
    Type = "String"))
'''

### Application Load Balancer ###

resources[ "ALB" ] = template.add_resource(AppLoadBalancer(
    "ALB",
    DependsOn = [ resource for resource in [ "ALBSecurityGroup" ] ],
    Name = Join("-", [ Ref(parameters[ "Project" ]), "alb" ]),
    Scheme = "internet-facing",
    SecurityGroups = [ Ref(resources[ "ALBSecurityGroup" ]) ],
    Subnets = [ ImportValue("PUBA"), ImportValue("PUBB") ],
    Tags = [ { "Key": "Name", "Value": Join("-", [ Ref(parameters[ "Project" ]), "alb" ]) },
             { "Key": "Project", "Value": Ref(parameters[ "Project" ]) } ] ))

### Application Load Balancer Listeners ###

resources[ "ALBHTTPlistener" ] = template.add_resource(AppListener(
    "ALBHTTPlistener",
    DependsOn = [ resource for resource in [ "ALB", "ALBTargetGroup" ] ],
    DefaultActions = [ Action( Type = 'forward', TargetGroupArn = Ref("ALBTargetGroup") )],
#        DefaultActions = [ Action( Type = 'redirect', RedirectConfig = RedirectActionConfig(
#            Host = "#{host}",
#            Path = "#{path}",
#            Port = "443",
#            Protocol = "HTTPS",
#            Query = "#{query}",
#            StatusCode = "HTTP_301"
#            ) ) ],
    LoadBalancerArn = Ref(resources[ "ALB" ]),
    Port = 80,
    Protocol = "HTTP"
    ))

'''
resources[ "ALBHTTPSlistener" ] = template.add_resource(AppListener(
    "ALBHTTPSlistener",
    DependsOn = [ resource for resource in [ "ALB", "ALBTargetGroup" ] ],
    Certificates = [ Certificate(
        "ALBCertificate",
        CertificateArn = Ref(parameters ["SSLCertificateALB"]))
        ],
    DefaultActions = [ Action( Type = 'forward', TargetGroupArn = Ref("ALBTargetGroup") )],
    LoadBalancerArn = Ref(resources[ "ALB" ]),
    Port = 443,
    Protocol = "HTTPS"
    ))
'''

### Application Load Balancer Target Group ###

resources[ "ALBTargetGroup" ] = template.add_resource(TargetGroup(
    "ALBTargetGroup",
    DependsOn = [ resource for resource in [ "ALB" ] ],
    HealthCheckIntervalSeconds = 10,
    HealthCheckPath = "/hello",
    HealthCheckProtocol = "HTTP",
    HealthCheckTimeoutSeconds = 5,
    HealthyThresholdCount = 3,
    Port = 80,
    Protocol = "HTTP",
    Tags = [ { "Key": "Project", "Value": Ref(parameters[ "Project" ]) } ],
    TargetGroupAttributes = [
        TargetGroupAttribute(
            Key = "deregistration_delay.timeout_seconds",
            Value = "90"),
        TargetGroupAttribute(
            Key = "stickiness.enabled",
            Value = "true"),
        TargetGroupAttribute(
            Key = "stickiness.type",
            Value = "lb_cookie")],
    TargetType = "ip",
    UnhealthyThresholdCount = 3,
    VpcId = ImportValue("VPC")
    ))

### ECS Cluster ###

resources["HelloWorldECSCluster"] = template.add_resource(Cluster(
    "HelloWorldECSCluster",
    ClusterName = Join("-", [ Ref(parameters[ "Project" ]), "cluster" ])
    ))

### ECS Task Definition IAM Role ###

resources["HelloWorldTaskExecutionRole"] = template.add_resource(Role(
    "HelloWorldTaskExecutionRole",
    AssumeRolePolicyDocument = {
        "Version": "2008-10-17",
        "Statement": [
            {
                "Sid": "",
                "Effect": "Allow",
                "Principal": {
                    "Service": "ecs-tasks.amazonaws.com"
                    },
                "Action": "sts:AssumeRole"
            }
        ]
    },
    ManagedPolicyArns = [  "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" ],
    Path = "/",
    RoleName = "HelloWorldTaskExecutionRole"
    ))

### ECS Task Definition ###

resources[ "HelloWorldTaskDef" ] = template.add_resource(TaskDefinition(
    "HelloWorldTaskDef",
    ContainerDefinitions = [ ContainerDefinition(
        "HelloWorldContDef",
        Cpu = 512,
        Image = "andreaarduino/arduino-hello-world:v4",
        Memory = 1024,
        Name = "hello-world",
        PortMappings = [ PortMapping(
            "HelloWorldPortMapping",
            ContainerPort = 80,
            HostPort = 80,
            Protocol = "tcp"
            )],
        )],
    Cpu = "512",
    ExecutionRoleArn = GetAtt(resources[ "HelloWorldTaskExecutionRole" ], "Arn"),
    Memory = "1024",
    NetworkMode = "awsvpc",
    RequiresCompatibilities = [ "FARGATE" ]
    ))

### ECS Service ###

resources[ "HelloWorldECSService" ] = template.add_resource(Service(
    "HelloWorldECSService",
    DependsOn = [ resource for resource in [ "ALBHTTPlistener", "HelloWorldTaskDef", "HelloWorldECSCluster" ] ],
    Cluster = GetAtt(template.resources[ "HelloWorldECSCluster" ], "Arn"),
    DeploymentConfiguration = DeploymentConfiguration(
        "HelloWorldECSDeployConf",
        MaximumPercent = 100,
        MinimumHealthyPercent = 0),
    DesiredCount = 1,
    HealthCheckGracePeriodSeconds = 300,
    LaunchType = "FARGATE",
    LoadBalancers = [ LoadBalancer(
        "HelloWorldECSServiceLB",
        ContainerName = "hello-world",
        ContainerPort = 80,
        TargetGroupArn = Ref(resources[ "ALBTargetGroup" ]),
        )],
    NetworkConfiguration = NetworkConfiguration(
        "HelloWorldNetConf",
        AwsvpcConfiguration = AwsvpcConfiguration(
            "HelloWorldVPCConf",
            AssignPublicIp = "DISABLED",
            SecurityGroups = [ Ref(resources[ "HelloWorldECSTaskSecurityGroup" ])],
            Subnets = [ ImportValue("PRVA"), ImportValue("PRVB") ]
            )
    ),
    ServiceName = Join("-", [ Ref(parameters[ "Project" ]), "ecs", "service" ]),
    TaskDefinition = Ref(resources[ "HelloWorldTaskDef" ])
    ))

### Route 53 ###

resources["HelloWorldRecordSetGroup"] = template.add_resource(RecordSetGroup(
      "HelloWorldRecordSetGroup",
      HostedZoneId = Ref(parameters["Route53HostedZoneID"]),
      RecordSets = [
          RecordSet(
          "HelloWorldRecordSetGroup",
          AliasTarget = AliasTarget(
              DNSName = GetAtt( resources["ALB"], "DNSName" ),
              HostedZoneId = GetAtt( resources[ "ALB" ], "CanonicalHostedZoneID" )),
          Name = "arduino-hello-world.com",
          Type = "A")
          ]))

### Template JSON ###

output = open(path.dirname(path.abspath(__file__))+"/"+path.splitext(path.basename(__file__))[ 0 ] + ".json", "w")
#print(template.to_json())
output.write(template.to_json())
output.close()
