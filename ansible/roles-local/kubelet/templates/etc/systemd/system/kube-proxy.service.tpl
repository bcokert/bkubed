[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
Before=kubelet.service

[Service]
ExecStart=/usr/bin/kube-proxy --kubeconfig=/var/lib/kubelet/kubeconfig
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
