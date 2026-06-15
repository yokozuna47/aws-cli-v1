#!/bin/bash

VPC_ID="vpc-0f7cd0ee42bee14a1"

create_nacl() {
    local nacl_name="$1"
    aws ec2 create-network-acl \
        --vpc-id $VPC_ID \
        --tag-specifications "ResourceType=network-acl,Tags=[{Key=Name,Value=$nacl_name}]"
}

delete_nacl() {
    local nacl_name="$1"
    local nacl_id
    nacl_id=$(aws ec2 describe-network-acls \
        --filters "Name=tag:Name,Values=$nacl_name" \
        --query "NetworkAcls[0].NetworkAclId" \
        --output text)
    aws ec2 delete-network-acl --network-acl-id "$nacl_id"
}

case "$1" in
    create) create_nacl "$2" ;;
    delete) delete_nacl "$2" ;;
    *) echo "Usage: $0 {create|delete} <nacl_name>" ;;
esac
