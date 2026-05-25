# Traefik TLS — HTTPS com certificado válido

O cluster usa Traefik com Gateway API. O listener `websecure` (porta 443) termina TLS. Por padrão o cert instalado é self-signed — browsers mostram "Not Secure".

Duas opções para resolver, dependendo do contexto.

---

## Opção A — Instalar a CA do cluster no OS (homelab pessoal)

O cert do Traefik é assinado por uma CA interna (`MyKubernetes CA`). Instalar essa CA no trust store do OS faz o browser confiar em todos os certs emitidos por ela — sem alterar nada no cluster.

**1. Exportar a CA:**
```bash
kubectl get secret traefik-cert -n traefik \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > mykubernetes-ca.crt
```

**2. Instalar no macOS:**
```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain mykubernetes-ca.crt
```
Reinicia Chrome/Safari após instalar.

**3. Instalar no Linux (Debian/Ubuntu):**
```bash
sudo cp mykubernetes-ca.crt /usr/local/share/ca-certificates/mykubernetes-ca.crt
sudo update-ca-certificates
```

**4. Instalar no Firefox** (trust store própria — independente do OS):

`Settings → Privacy & Security → Certificates → View Certificates → Authorities → Import`

Seleciona `mykubernetes-ca.crt` → marca **Trust this CA to identify websites** → OK.

**5. Verificar:**
```bash
curl -v https://<cluster-ip>/frontend/healthz
# deve mostrar: SSL certificate verify ok
```

> Quando usar: acesso pessoal ao homelab, sem domínio público. Zero mudanças no cluster.

---

## Opção B — Usar wildcard cert com domínio próprio

Se tens um domínio e um wildcard cert já instalado no cluster como secret no namespace `traefik`, podes configurar o Gateway para usá-lo.

**1. Verificar o secret do cert:**
```bash
kubectl get secrets -n traefik | grep tls
# identifica o secret com o wildcard cert (ex: my-wildcard-cert)

kubectl get secret my-wildcard-cert -n traefik \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -ext san
# confirma que o cert cobre o domínio desejado
```

**2. Criar registro DNS:**

No teu DNS provider, cria um registro A:
```
system-design.yourdomain.com → <IP do cluster>
```

Para ambiente interno (sem DNS público), adiciona no `/etc/hosts` de cada máquina que aceder:
```
192.168.1.131  system-design.yourdomain.com
```

**3. Atualizar o Gateway listener** para usar o wildcard cert:
```bash
kubectl patch gateway traefik-gateway -n traefik --type=json -p='[
  {
    "op": "replace",
    "path": "/spec/listeners/1/tls/certificateRefs/0",
    "value": {
      "kind": "Secret",
      "name": "my-wildcard-cert",
      "namespace": "traefik"
    }
  }
]'
```

> Substitui `my-wildcard-cert` pelo nome real do secret.  
> O índice `1` assume que `websecure` é o segundo listener (web=0, websecure=1). Confirma com:
> ```bash
> kubectl get gateway traefik-gateway -n traefik \
>   -o jsonpath='{.spec.listeners[*].name}'
> ```

**4. Adicionar `hostnames` nos HTTPRoutes:**

Sem `hostnames`, o route aceita qualquer hostname — o browser pode receber o cert errado. Com wildcard cert, restringe ao hostname correto.

`devsecops/k8s/apps/frontend/httproute.yaml`:
```yaml
spec:
  hostnames:
    - system-design.yourdomain.com
  parentRefs:
    - name: traefik-gateway
      namespace: traefik
      sectionName: websecure
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /frontend
      filters:
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /
      backendRefs:
        - name: frontend-stable
          port: 8000
          weight: 100
        - name: frontend-canary
          port: 8000
          weight: 0
```

Aplica o mesmo `hostnames` no `backend/httproute.yaml`.

**5. Aplicar e testar:**
```bash
kubectl apply -f devsecops/k8s/apps/frontend/httproute.yaml
kubectl apply -f devsecops/k8s/apps/backend/httproute.yaml

curl -v https://system-design.yourdomain.com/frontend/healthz
curl -v https://system-design.yourdomain.com/backend/healthz
```

> Quando usar: domínio público ou wildcard cert já existente no cluster. URL "real" acessível por outras pessoas.

---

## Opção C — cert-manager + Let's Encrypt (automático)

Para ambientes com domínio público e acesso à internet. cert-manager renova os certs automaticamente.

**1. Instalar cert-manager:**
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
kubectl wait --for=condition=Available deployment -n cert-manager --all --timeout=120s
```

**2. Criar ClusterIssuer (Let's Encrypt):**
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your@email.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          gatewayHTTPRoute:
            parentRefs:
              - name: traefik-gateway
                namespace: traefik
                kind: Gateway
```

**3. Criar Certificate:**
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: system-design-cert
  namespace: traefik
spec:
  secretName: system-design-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - system-design.yourdomain.com
```

**4. Atualizar Gateway listener** após o cert ser emitido:
```bash
# aguarda emissão (~60s)
kubectl wait certificate system-design-cert -n traefik \
  --for=condition=Ready --timeout=120s

# atualiza o listener para usar o novo secret
kubectl patch gateway traefik-gateway -n traefik --type=json -p='[
  {
    "op": "replace",
    "path": "/spec/listeners/1/tls/certificateRefs/0",
    "value": {
      "kind": "Secret",
      "name": "system-design-tls",
      "namespace": "traefik"
    }
  }
]'
```

> Quando usar: domínio público com DNS resolvível pela internet. HTTP-01 challenge requer que a porta 80 seja acessível publicamente.  
> Para domínios internos sem exposição pública, usa DNS-01 challenge com o provider do teu domínio.

---

## Resumo

| Opção | Requisito | Mudança no cluster | Melhor para |
|-------|-----------|-------------------|-------------|
| A — Instalar CA no OS | Nenhum | Nenhuma | Homelab pessoal, acesso local |
| B — Wildcard cert existente | Domínio + cert no cluster | Gateway patch + hostnames | Cert já disponível |
| C — cert-manager + Let's Encrypt | Domínio público + porta 80 exposta | cert-manager + ClusterIssuer | Produção, renovação automática |
