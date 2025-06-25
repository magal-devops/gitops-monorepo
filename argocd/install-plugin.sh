#!/bin/bash

set -e

echo "🚀 Instalando plugin helm-values-merger no ArgoCD..."

# 1. Aplicar o ConfigMap do plugin
echo "📝 Aplicando ConfigMap do plugin..."
kubectl apply -f argocd-cmp-plugin.yaml

# 2. Verificar se o ConfigMap foi criado
echo "✅ Verificando ConfigMap..."
kubectl get configmap argocd-cmp-plugin -n argocd

# 3. Adicionar volume do plugin
echo "🔧 Adicionando volume do plugin..."
# kubectl patch deployment argocd-repo-server -n argocd --type='json' -p='[
#   {
#     "op": "add",
#     "path": "/spec/template/spec/volumes/-",
#     "value": {
#       "name": "cmp-plugin",
#       "configMap": {
#         "name": "argocd-cmp-plugin"
#       }
#     }
#   }
# ]'

# 4. Adicionar volume tmp separado para o plugin
# echo "🔧 Adicionando volume tmp separado..."
# kubectl patch deployment argocd-repo-server -n argocd --type='json' -p='[
#   {
#     "op": "add",
#     "path": "/spec/template/spec/volumes/-",
#     "value": {
#       "name": "cmp-tmp",
#       "emptyDir": {}
#     }
#   }
# ]'

# 5. Adicionar sidecar container
echo "🔧 Adicionando sidecar container..."
kubectl patch deployment argocd-repo-server -n argocd --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/-",
    "value": {
      "name": "helm-values-merger",
      "image": "quay.io/argoproj/argocd:v2.14.7",
      "command": ["/var/run/argocd/argocd-cmp-server"],
      "env": [
        {
          "name": "ARGOCD_EXEC_TIMEOUT",
          "value": "60s"
        },
        {
          "name": "ARGOCD_BINARY_NAME",
          "value": "argocd-cmp-server"
        }
      ],
      "securityContext": {
        "runAsNonRoot": true,
        "runAsUser": 999,
        "readOnlyRootFilesystem": true,
        "allowPrivilegeEscalation": false,
        "capabilities": {
          "drop": ["ALL"]
        },
        "seccompProfile": {
          "type": "RuntimeDefault"
        }
      },
      "volumeMounts": [
        {
          "name": "var-files",
          "mountPath": "/var/run/argocd"
        },
        {
          "name": "plugins",
          "mountPath": "/home/argocd/cmp-server/plugins"
        },
        {
          "name": "cmp-plugin",
          "mountPath": "/home/argocd/cmp-server/config/plugin.yaml",
          "subPath": "plugin.yaml"
        },
        {
          "name": "cmp-tmp",
          "mountPath": "/tmp"
        }
      ],
      "workingDir": "/home/argocd/cmp-server",
      "resources": {}
    }
  }
]'

# 6. Aguardar o rollout
echo "⏳ Aguardando rollout do deployment..."
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s

# 7. Verificar se o plugin foi carregado
echo "🔍 Verificando logs do plugin..."
sleep 10
kubectl logs -n argocd deployment/argocd-repo-server -c helm-values-merger --tail=20 || echo "Ainda carregando..."

# 8. Aplicar o ApplicationSet
echo "📋 Aplicando ApplicationSet..."
kubectl apply -f applications-set.yaml

echo "✅ Plugin instalado com sucesso!"
echo ""
echo "Para verificar o status:"
echo "  kubectl get applicationset -n argocd"
echo "  kubectl get applications -n argocd"
echo ""
echo "Para debug:"
echo "  kubectl logs -n argocd deployment/argocd-repo-server -c helm-values-merger"
echo ""
echo "Para desinstalar:"
echo "  ./uninstall-plugin.sh" 