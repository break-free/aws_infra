#pre-req
# chocolatey -> awk and grep
# AWS cli w/ credential configured

begin{
    $clusterName = Read-Host -Prompt "EKS Cluster Name?"   
}
process{
$vpcId = aws eks describe-cluster --name $ClusterName --query 'cluster.resourcesVpcConfig.vpcId'

aws elbv2 describe-load-balancers --query LoadBalancers[*].[DNSName,VpcId] --output text | grep $vpcId | awk '{print $1}'
}