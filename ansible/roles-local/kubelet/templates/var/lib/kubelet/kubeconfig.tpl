apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: {{k8s_certs_dir}}/{{k8s_certs_kube_ca}}
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
    client-certificate: {{k8s_certs_dir}}/{{k8s_certs_kubelet}}
    client-key: {{k8s_keys_dir}}/{{k8s_keys_kubelet}}
