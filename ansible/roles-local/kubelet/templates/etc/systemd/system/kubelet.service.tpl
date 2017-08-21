[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/kubelet \
  --allow-privileged=true \
  --cloud-provider=aws \
  --cluster-dns={{k8s_cluster_dns_ip}} \
  --cluster-domain={{k8s_cluster_domain}} \
  --container-runtime=docker \
  --network-plugin=cni \
  --network-plugin-dir=/etc/cni/net.d \
  --cni-bin-dir=/opt/cni/bin \
  --cni-conf-dir=/etc/cni/net.d \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --serialize-image-pulls=false \
  --register-node=true \
  --require-kubeconfig \
  --tls-cert-file=/etc/ssl/certs/{{k8s_certs_kubelet}} \
  --tls-private-key-file=/etc/ssl/keys/{{k8s_keys_kubelet}} \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
