import pulumi
import pulumi_aws as aws
import pulumi_tls as tls
import os

config = pulumi.Config()
instance_type = config.get("instanceType")
if instance_type is None:
    instance_type = "t3.micro"
vpc_network_cidr = config.get("vpcNetworkCidr")
if vpc_network_cidr is None:
    vpc_network_cidr = "10.0.0.0/16"

ami = aws.ec2.get_ami(
    filters=[
        aws.ec2.GetAmiFilterArgs(
            name="name",
            values=["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-*"],
        ),
        aws.ec2.GetAmiFilterArgs(
            name="virtualization-type",
            values=["hvm"],
        ),
        aws.ec2.GetAmiFilterArgs(
            name="architecture",
            values=["arm64"],
        ),
    ],
    owners=["099720109477"],
    most_recent=True,
).id

ssh_key = tls.PrivateKey("ec2-key", algorithm="RSA", rsa_bits=4096)
ec2_key_pair = aws.ec2.KeyPair(
    "ec2-key-pair",
    key_name=pulumi.Output.concat(
        pulumi.get_project(), "-", pulumi.get_stack(), "-ec2-key"
    ),
    public_key=ssh_key.public_key_openssh,
)

vpc = aws.ec2.Vpc(
    "vpc",
    cidr_block=vpc_network_cidr,
    assign_generated_ipv6_cidr_block=True,
    enable_dns_hostnames=True,
    enable_dns_support=True,
)

gateway = aws.ec2.InternetGateway("gateway", vpc_id=vpc.id)

subnet = aws.ec2.Subnet(
    "subnet",
    vpc_id=vpc.id,
    cidr_block="10.0.1.0/24",
    ipv6_cidr_block=vpc.ipv6_cidr_block.apply(
        lambda cidr: f"{cidr.split('::')[0]}::/64"
    ),
    assign_ipv6_address_on_creation=True,
    map_public_ip_on_launch=False,
)

route_table = aws.ec2.RouteTable(
    "routeTable",
    vpc_id=vpc.id,
    routes=[
        aws.ec2.RouteTableRouteArgs(
            ipv6_cidr_block="::/0",
            # cidr_block="0.0.0.0/0",
            gateway_id=gateway.id,
        ),
    ],
)

route_table_association = aws.ec2.RouteTableAssociation(
    "routeTableAssociation", subnet_id=subnet.id, route_table_id=route_table.id
)

sec_group = aws.ec2.SecurityGroup(
    "secGroup",
    description="Enable HTTPS & SSH access",
    vpc_id=vpc.id,
    ingress=[
        aws.ec2.SecurityGroupIngressArgs(
            description="HTTPS",
            protocol="tcp",
            from_port=443,
            to_port=443,
            cidr_blocks=["0.0.0.0/0"],
            ipv6_cidr_blocks=["::/0"],
        ),
        aws.ec2.SecurityGroupIngressArgs(
            description="Allow SSH from any IPv6 address",
            protocol="tcp",
            from_port=22,
            to_port=22,
            cidr_blocks=["0.0.0.0/0"],
            ipv6_cidr_blocks=["::/0"],
        ),
    ],
    egress=[
        aws.ec2.SecurityGroupEgressArgs(
            protocol="-1",
            from_port=0,
            to_port=0,
            cidr_blocks=["0.0.0.0/0"],
            ipv6_cidr_blocks=["::/0"],
        ),
    ],
)

server = aws.ec2.Instance(
    "server",
    instance_type=instance_type,
    subnet_id=subnet.id,
    key_name=ec2_key_pair.key_name,
    vpc_security_group_ids=[sec_group.id],
    ami=ami,
    root_block_device=aws.ec2.InstanceRootBlockDeviceArgs(
        volume_size=15,
        volume_type="gp3",
        delete_on_termination=True,
    ),
)


def save_private_key(key_pem):
    filename = "key.pem"

    try:
        with open(filename, "w") as f:
            f.write(key_pem)

        os.chmod(filename, 0o600)
        pulumi.log.info(f"Private key saved to '{filename}'")
        return filename
    except Exception as e:
        pulumi.log.error(f"Failed to save private key: {e}")
        raise


private_key_path_output = ssh_key.private_key_pem.apply(save_private_key)

pulumi.export("ipv6", server.ipv6_addresses[0])
pulumi.export("keypair name", ec2_key_pair.key_name)
