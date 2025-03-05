# Перед применением манифеста добавлялся репозиторий
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm update

# Создается новый IngressClass чтобы не мешать работе старому контроллеру
set {
  name  = "controller.ingressClass"
  value = "nginx-new"  # Указывает контроллеру обрабатывать Ingressы с этим классом
}

# Меняется имя контроллера
resource "helm_release" "custom_nginx" {
  name       = "ingress-nginx"  # ⚠️ Опасно, если в кластере уже есть релиз с таким именем!
  ...
}

# В манифест явно добавляется включение параметра ресурса ingress (по умолчанию true, но лучше явно указать)
set {
  name  = "controller.ingressClassResource.enabled"
  value = "true"
}

# Проверка создания IngressClass
kubectl get ingressclass

# Новый ingress использует автоматический ip с нового LoadBalancer

# Рекомендации по переходу
Постепенный переход для миграции:
- Разверните новый контроллер с классом nginx-new.
- Создавайте новые Ingress-ресурсы с ingressClassName: nginx-new.
- Постепенно обновляйте старые Ingressы, добавляя им ingressClassName: nginx-new, когда убедитесь в стабильности нового контроллера.
- Удалите старый контроллер после полного перехода.

# Проверка включения http3
kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- nginx -V 2>&1 | grep -i http_v3

Должна быть строка: --with-http_v3_module

nmap -sU -p 443 LoadBalancerIP

Должно отобразиться:

PORT    STATE         SERVICE

443/udp open|filtered https
