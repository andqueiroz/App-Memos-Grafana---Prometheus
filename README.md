# Lab DevOps: Observabilidade e Web App com K3s na AWS

Este projeto provisiona uma infraestrutura efêmera na AWS utilizando Terraform, GitHub Actions, Docker e Kubernetes (K3s). O ambiente hospeda duas aplicações acessíveis via HTTPS (AWS ALB):
1. **Memos:** Aplicação web para anotações (estilo Obsidian/OneNote).
2. **Observabilidade:** Stack Prometheus e Grafana.

## 🚀 Arquitetura
- **CI/CD:** GitHub Actions com validação em cluster local (KinD) antes do deploy.
- **Infraestrutura:** AWS EC2 (t3.medium) rodando K3s, exposta via AWS Application Load Balancer (ALB).
- **Segurança:** Tráfego HTTPS garantido por um certificado autoassinado gerado via Terraform e gerenciado pelo AWS Certificate Manager (ACM).

## 🛠️ Pré-requisitos
Para rodar este pipeline, configure as seguintes **Secrets** no seu repositório do GitHub (`Settings > Secrets and variables > Actions`):
- `AWS_ACCESS_KEY_ID`: Sua chave de acesso da AWS.
- `AWS_SECRET_ACCESS_KEY`: Sua chave secreta da AWS.
- `AWS_REGION`: Ex: `us-east-1`.

## ⚙️ Como usar

1. **Deploy Automático:** Qualquer `push` na branch `main` acionará o workflow de deploy. O pipeline testará os manifestos no KinD e, se aprovado, criará a infraestrutura na AWS. O DNS do ALB será exibido nos logs finais do Terraform.
2. **Destruição (Importante para economizar os $50):** Vá na aba "Actions" no GitHub, selecione o workflow `Destroy AWS Environment` e clique em "Run workflow". Isso executará o `terraform destroy`.