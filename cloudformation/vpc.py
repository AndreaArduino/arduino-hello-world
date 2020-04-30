from os import path
from troposphere import AWS_REGION, Export, Join, Output, Parameter, Ref, Template, GetAtt
from troposphere.ec2 import InternetGateway, Route, RouteTable, Subnet, SubnetRouteTableAssociation, VPC, VPCGatewayAttachment, EIP, NatGateway

### Template Definition ###

template = Template()
template.description = "Hello world project VPC"

### Template Parameters ###

parameters = {}

parameters[ "Project" ] = template.add_parameter(Parameter(
    "Project",
    Type="String",
    Description="Project Name",
    Default="hello-world"))

### Template Resources ###

resources = {}

### VPC ###

resources[ "VPC" ] = template.add_resource(VPC(
    "VPC",
    CidrBlock = "10.0.0.0/24",
    EnableDnsHostnames = True,
    EnableDnsSupport = True,
    Tags = [ { "Key": "Name", "Value": Join("-", [ Ref(parameters[ "Project" ]), "vpc" ]) },
             { "Key": "Project", "Value": Ref(parameters[ "Project" ]) }]))

### Internet Gateway ###

resources[ "InternetGateway" ] = template.add_resource(InternetGateway(
    "InternetGateway",
    Tags = [ { "Key": "Name", "Value": Join("-", [ Ref(parameters[ "Project" ]), "igw" ]) },
             { "Key": "Project", "Value": Ref(parameters[ "Project" ]) }]))
resources[ "VPCGatewayAttachmentIGW" ] = template.add_resource(VPCGatewayAttachment(
    "VPCGatewayAttachmentIGW",
    DependsOn = [ resource for resource in [ "InternetGateway",
                                             "VPC" ] ],
    InternetGatewayId = Ref(resources[ "InternetGateway" ]),
    VpcId = Ref(resources[ "VPC" ] )))

### Routing Tables ###

resources[ "PrivateRouteTableA" ] = template.add_resource(RouteTable(
    "PrivateRouteTableA",
    DependsOn = [ resource for resource in [ "VPC" ] ],
    Tags = [ { "Key": "Name", "Value": Join("-", [ Ref(parameters[ "Project" ]), "prv", "a", "rt" ]) },
             { "Key": "Project", "Value": Ref(parameters[ "Project" ]) }],
    VpcId = Ref(resources[ "VPC" ])))

resources[ "PrivateRouteTableB" ] = template.add_resource(RouteTable(
    "PrivateRouteTableB",
    DependsOn = [ resource for resource in [ "VPC" ] ],
    Tags = [ { "Key": "Name", "Value": Join("-", [ Ref(parameters[ "Project" ]), "prv", "b", "rt" ]) },
             { "Key": "Project", "Value": Ref(parameters[ "Project" ]) }],
    VpcId = Ref(resources[ "VPC" ])))

resources[ "PublicRouteTable" ] = template.add_resource(RouteTable(
    "PublicRouteTable",
    DependsOn = [ resource for resource in [ "VPC" ] ],
    Tags = [ { "Key": "Name", "Value": Join("-", [ Ref(parameters[ "Project" ]), "pub", "rt" ]) },
             { "Key": "Project", "Value": Ref(parameters[ "Project" ]) } ],
    VpcId = Ref(resources[ "VPC" ])))

### Subnets ###

azlist = [ Join("", [ Ref(AWS_REGION), "a" ]),
           Join("", [ Ref(AWS_REGION), "b" ]) ]

subnetlist = [ "PUBA",
               "PUBB",
               "PRVA",
               "PRVB"]

cidr_list = [ "10.0.0.0/26",
              "10.0.0.64/26",
              "10.0.0.128/26",
              "10.0.0.192/26"]

i = 0
for subnet in subnetlist:
    resources[ subnet ] = template.add_resource(Subnet(
        subnet,
        DependsOn = [ resource for resource in [ "VPC" ] ],
        AvailabilityZone = azlist[ 0 ] if "A" in subnet else azlist[ 1 ],
        CidrBlock = cidr_list[i],
        Tags = [ { "Key": "Name", "Value": Join("-", [ Ref(parameters[ "Project" ]), subnet.lower() ]) },
                 { "Key": "Project", "Value": Ref(parameters[ "Project" ]) }],
        VpcId = Ref(resources[ "VPC" ])))

    if "PRV" in subnet:
        if "A" in subnet:
            routetable = resources[ "PrivateRouteTableA" ]
        else:
            routetable = resources[ "PrivateRouteTableB" ]
    else:
        routetable = resources[ "PublicRouteTable" ]

    template.add_resource(SubnetRouteTableAssociation(
        "SubnetRouteTableAssociation" + subnet,
        DependsOn = [ resource for resource in [ routetable.name,
                                                 subnet ] ],
        RouteTableId = Ref(routetable),
        SubnetId = Ref(resources[ subnet ])))

    i = i+1

### Elastic IP for NAT Gateway ###

resources[ "ElasticIP" ] = template.add_resource(EIP(
    "ElasticIP",
    DependsOn = [ resource for resource in [ "VPCGatewayAttachmentIGW" ] ],
    Domain = "vpc"
))

### NAT Gateway ###

resources[ "NatGateway" ] = template.add_resource(NatGateway(
    "NatGateway",
    DependsOn = [ resource for resource in [ "PUBA", "ElasticIP" ] ],
    AllocationId = GetAtt(resources[ "ElasticIP" ], "AllocationId" ),
    SubnetId = Ref(resources[ "PUBA" ])))

### Routes ###

template.add_resource(Route(
    "InternetGatewayRoute",
    DependsOn = [ resource for resource in [ "VPCGatewayAttachmentIGW" ] ],
    DestinationCidrBlock = "0.0.0.0/0",
    GatewayId = Ref(resources[ "InternetGateway" ]),
    RouteTableId = Ref(resources[ "PublicRouteTable" ])))

for routetable in [ "PrivateRouteTableA", "PrivateRouteTableB" ]:
    template.add_resource(Route(
        "NatGatewayRoute" + routetable,
        DependsOn = [ resource for resource in [ "NatGateway" ] ],
        DestinationCidrBlock = "0.0.0.0/0",
        NatGatewayId = Ref(resources[ "NatGateway" ]),
        RouteTableId = Ref(routetable)))

### Template Outputs ###

for parameter in parameters:
    template.add_output(Output(
        parameter,
        Description = parameter,
        Value = Ref(parameters[ parameter ])))
for name, resource in resources.items():
    template.add_output(Output(
        name,
        Description = name,
        Export = Export(name),
        Value = Ref(resource)))

### Template JSON ###
output = open(path.dirname(path.abspath(__file__))+"/"+path.splitext(path.basename(__file__))[ 0 ] + ".json", "w")
#print(template.to_json())
output.write(template.to_json())
output.close()
