apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: {{k8s_certs_kube_ca}}
    server: http://127.0.0.1:8080
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: scheduler
  name: scheduler
current-context: scheduler
users:
- name: scheduler
  user:
