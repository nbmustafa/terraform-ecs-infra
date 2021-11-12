#cloud-boothook
# Configure the Docker daemon and the ECS agent to use an HTTP proxy, and configure the ECS cluster name.
# Based on sample at https://docs.aws.amazon.com/AmazonECS/latest/developerguide/http_proxy_config.html

PROXY_HOST=${proxy_host}
PROXY_PORT=3128
NO_PROXY=localhost,169.254.169.254,patching-server-hui.ext.krd.com.au,.krd.com.au
CLUSTER_NAME=${cluster_name}

# Set Docker HTTP proxy
if [ ! -f /var/lib/cloud/instance/sem/config_docker_http_proxy ]; then
	echo "export HTTP_PROXY=http://$PROXY_HOST:$PROXY_PORT/" >> /etc/sysconfig/docker
	echo "export HTTPS_PROXY=http://$PROXY_HOST:$PROXY_PORT/" >> /etc/sysconfig/docker
	echo "export NO_PROXY=$NO_PROXY,169.254.170.2" >> /etc/sysconfig/docker
	echo "$$: $(date +%s.%N | cut -b1-13)" > /var/lib/cloud/instance/sem/config_docker_http_proxy
fi
# Set ECS agent HTTP proxy and ECS cluster name
if [ ! -f /var/lib/cloud/instance/sem/config_ecs-agent_http_proxy ]; then
	echo "ECS_CLUSTER=$CLUSTER_NAME" >> /etc/ecs/ecs.config
	echo "HTTP_PROXY=$PROXY_HOST:$PROXY_PORT" >> /etc/ecs/ecs.config
	echo "HTTPS_PROXY=$PROXY_HOST:$PROXY_PORT" >> /etc/ecs/ecs.config
	echo "NO_PROXY=$NO_PROXY,169.254.170.2,/var/run/docker.sock" >> /etc/ecs/ecs.config
	echo "$$: $(date +%s.%N | cut -b1-13)" > /var/lib/cloud/instance/sem/config_ecs-agent_http_proxy
fi
# Set ecs-init HTTP proxy
if [ ! -f /var/lib/cloud/instance/sem/config_ecs-init_http_proxy ]; then
	echo "env HTTP_PROXY=$PROXY_HOST:$PROXY_PORT" >> /etc/init/ecs.override
	echo "env HTTPS_PROXY=$PROXY_HOST:$PROXY_PORT" >> /etc/init/ecs.override
	echo "env NO_PROXY=$NO_PROXY,169.254.170.2,/var/run/docker.sock" >> /etc/init/ecs.override
	echo "$$: $(date +%s.%N | cut -b1-13)" > /var/lib/cloud/instance/sem/config_ecs-init_http_proxy
fi

echo "Signalling cfn to proceed `date +"%T"`"

STACK=${stack_name}
RESOURCE=${resource}
REGION=${aws_region}

sudo yum install -y aws-cfn-bootstrap

/opt/aws/bin/cfn-signal \
  --exit-code $? \
  --stack $STACK \
  --resource $RESOURCE \
  --region $REGION \
  --http-proxy "http://$PROXY_HOST:$PROXY_PORT" \
  --https-proxy "http://$PROXY_HOST:$PROXY_PORT"
