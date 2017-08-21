apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: {{k8s_certs_dir}}/{{k8s_certs_root_ca}}
    server: {{k8s_api_server}}
  name: bkubed
contexts:
- context:
    cluster: bkubed
    user: kubelet
  name: kubelet
current-context: kubelet
users:
- name: kubelet
  user:
    token: {{k8s_token_kubelet}}
