[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-apiserver \
  --advertise-address=127.0.0.1 \
  --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota,Initializers \
  --runtime-config=admissionregistration.k8s.io/v1alpha1 \
  --allow-privileged=true \
  --apiserver-count=2 \
  --authorization-mode=ABAC,RBAC \
  --authorization-policy-file=/var/lib/kubernetes/authorization-policy.jsonl \
  --token-auth-file=/var/lib/kubernetes/tokens.csv \
  --bind-address=0.0.0.0 \
  --insecure-bind-address=0.0.0.0 \
  --service-cluster-ip-range={{k8s_service_cluster_ip_range}} \
  --service-node-port-range={{k8s_service_node_port_range}} \
  --enable-swagger-ui=true \
  --etcd-servers={{etcd_servers}} \
  --etcd-certfile={{k8s_certs_etcd_client}} \
  --etcd-keyfile={{k8s_keys_etcd_client}} \
  --etcd-cafile={{k8s_certs_kube_ca}} \
  --storage-backend=etcd3 \
  --tls-cert-file={{k8s_certs_api}} \
  --tls-private-key-file={{k8s_keys_api}} \
  --service-account-key-file={{k8s_keys_service_account}} \
  --kubelet-certificate-authority={{k8s_certs_kube_ca}} \
  --cloud-provider=aws \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
