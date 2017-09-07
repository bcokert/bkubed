[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-controller-manager \
  --allocate-node-cidrs=true \
  --cluster-cidr={{k8s_cluster_cidr}} \
  --cluster-name={{k8s_cluster_name}} \
  --leader-elect=true \
  --master=http://127.0.0.1:8080 \
  --service-cluster-ip-range={{k8s_service_cluster_ip_range}} \
  --service-account-private-key-file={{k8s_keys_service_account}} \
  --root-ca-file={{k8s_kube_ca_cert}} \
  --cloud-provider=aws \
  --configure-cloud-routes=false \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
