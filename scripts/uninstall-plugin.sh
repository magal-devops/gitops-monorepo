#!/bin/bash

set -e

echo "🧹 Desinstalando plugin helm-values-merger do ArgoCD..."

# 1. Remover ApplicationSet
echo "📋 Removendo ApplicationSet..."
kubectl delete applicationset applications-dynamic -n argocd || echo "ApplicationSet não encontrado (ok)"

# 2. Aguardar um pouco
sleep 5

# 3. Fazer backup do deployment atual
echo "💾 Fazendo backup do deployment..."
kubectl get deployment argocd-repo-server -n argocd -o yaml > argocd-repo-server-backup.yaml

# 4. Reiniciar deployment para estado original
echo "🔄 Restaurando deployment original..."
kubectl rollout undo deployment/argocd-repo-server -n argocd || echo "Rollback não disponível"

# Ou usar uma abordagem mais direta: remover patches específicos
echo "🗑️ Removendo patches do plugin..."

# Primeiro tentar remover container sidecar (pode estar em diferentes índices)
for i in {1..5}; do
  kubectl patch deployment argocd-repo-server -n argocd --type='json' -p="[{\"op\": \"remove\", \"path\": \"/spec/template/spec/containers/$i\"}]" 2>/dev/null && echo "Container $i removido" || true
done

# Depois remover volumes (podem estar em diferentes posições)
for i in {9..15}; do
  kubectl patch deployment argocd-repo-server -n argocd --type='json' -p="[{\"op\": \"remove\", \"path\": \"/spec/template/spec/volumes/$i\"}]" 2>/dev/null && echo "Volume $i removido" || true
done

# 5. Remover ConfigMap
echo "🗑️ Removendo ConfigMap..."
kubectl delete configmap argocd-cmp-plugin -n argocd || echo "ConfigMap não encontrado (ok)"

# 6. Aguardar rollout
echo "⏳ Aguardando rollout do deployment..."
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s

echo "✅ Plugin desinstalado com sucesso!"
echo ""
echo "Para reinstalar:"
echo "  ./install-plugin.sh" 