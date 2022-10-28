# Punto de partida para el TP 2 de Arquitectura de Software (75.73) del 2do cuatrimestre de 2022

> La fecha de entrega para el informe y el código será el __*jueves 24/11/2022 a las 17:59hs*__.
> La misma herramienta de GitHub Classroom nos va a mostrar el último commit que hayan hecho sobre `main` hasta ese momento, con lo que es un deadline fijo y estricto. :warning: :bangbang:

## Contexto

Para este Trabajo, nuestro servicio será una app hecha en Node que consumirá otro servicio (supuestamente externo, es decir, no se encuentra bajo nuestro control), hecho en Python. Nuestra aplicación tiene un endpoint que hace un passthrough al servicio externo.

Creando una sola instancia de la app en Node, deben encontrar el límite de ese endpoint, y mostrar cuál es el cuello de botella (los recursos de nuestro servicio, el servicio externo, el ancho de banda, o algún otro factor). Luego, deben escalar horizontalmente la app de Node y buscar el nuevo límite.

Cuando hayan finalizado el paso anterior, deben repetir introduciendo cache con Redis. No es necesario probar Redis con ambas configuraciones de la app Node (sin escalar y escalando horizontalmente), basta con que lo usen en *una* configuración y aclaren de cuál se trata.

Tanto para escalar horizontalmente como para agregar una instancia de Redis, cada grupo deberá modificar/agregar archivos de Terraform como sea necesario.

- Para escalar en un Virtual Machine Scaling Set (VMSS), ajustar el parámetro *instances* según lo deseado.
- Para crear una instancia de Redis en Azure, mirar el [recurso azurerm_redis_cache de Terraform](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/redis_cache).

## Setup

### Azure

- Crear una cuenta en Azure.
- Desde SSH Keys, generar un par de claves (key/secret).

### Datadog

- Crear una cuenta con el [pack estudiantil de GitHub](https://education.github.com/pack) en [Datadog](https://www.datadoghq.com/)
- Ir a `<Usuario> -> Organization Settings -> API Keys` y obtener la API KEY.

### Terraform

- Instalar Terraform, descargable desde [aquí](https://www.terraform.io/downloads).
- Crear dentro de este repository un archivo `terraform.tfvars` con los siguientes campos.

    ```properties
    datadog_key = "<API key de Datadog>"
    group_prefix = "<prefijo único para todo Azure, por integrante>"
    ```

    > _**ATENCIÓN: EVITEN COMMITEAR ESTE ARCHIVO AL REPOSITORIO. LAS API KEYS EN GENERAL NO DEBEN COMMITEARSE. DE HACERLO DEBEN ELIMINARLAS Y CREAR NUEVAS**
    _

- Revisar el archivo `variables.tf` y actualizar los valores default de las variables que corresponda. Para "location", recomendamos utilizar "eastus" o "westus2". Este archivo sí será commiteado, así que solo poner aquí valores default que puedan exponerse (para los demás, deben estar las variables definidas aquí pero los valores deben estar en `terraform.tfvars`, que nunca hay que commitearlo).
- Ejecutar `terraform init`. Esto inicializa la configuración que requiere terraform, e instala los providers necesarios.

### Ansible

- Instalar Ansible, ver [aquí](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) información para el SO que se tenga.

## Cheatsheet de terraform

```sh
# Ver lista de comandos
terraform help

# Ver ayuda de un comando específico, como por ejemplo qué parámetros/opciones acepta
terraform <COMMAND> --help

# Ver la versión de terraform instalada
terraform version

# Inicializar terraform en el directorio. Esto instala los providers e inicializa archivos de terraform
terraform init

# Ver el plan de ejecución pero sin realizar ninguna acción sobre la infraestructura (no lo aplica)
terraform plan

# Aplicar los cambios de infraestructura. Requiere aprobación manual, a menos que se especifique la opción `-auto-approve`
terraform apply

# Destruir toda la infraestructura. Requiere aprobación manual, a menos que se especifique la opción `-force`
terraform destroy

# Verifica que la sintaxis y la semántica de los archivos sea válida
terraform validate

# Lista los providers instalados. Para este tp, deben ser al menos "azurerm", "template", "time" y "local"
terraform providers
```

## Correr los servidores

> **IMPORTANTE:** Es necesario tener instalado el [`Azure CLI`](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli). Además, en el script se utiliza el binario de `terraform`, asumiendo que se encuentra agregado a la variable `$PATH` (si lo instalan con un package manager, ya estará en el path).
>

Existe el script `start.sh` en la raíz del proyecto para crear la infraestructura y correr los servidores correspondientes.

```bash
# Seteo los permisos apropiados para que la key sea válida
chmod 400 <KEY_SSH.pem>
# Creo un symlink a la key ssh, para que Ansible la encuentre
ln -s <KEY_SSH.pem> ansible/key.pem
# Guardo la clave pública que obtuve de Azure
echo <PUBLIC_KEY> > pubkey

# Script que inicia sesión en Azure, crea la infra y la inicializa
./start.sh
```

Terraform crea un archivo local llamado `terraform.tfstate` que tiene el resultado de la aplicación del plan. Usa ese archivo luego para detectar diferencias y definir un nuevo plan si hay modificaciones a la infraestructura. Ese archivo **no debe perderse**, pero como [puede contener información sensible en texto plano](https://www.terraform.io/docs/state/sensitive-data.html) no es recomendable commitearlo sin tomar algunas precauciones. Además, si se destruye y regenera la infraestructura, cambiará mucho, con lo que es muy propenso a conflictos en git.

La recomendación, por lo tanto, es que cada cual tenga su propia cuenta de Azure y de Datadog, y mantenga su propio `terraform.tfstate` en su computadora sin necesidad de compartirlo. [Acá](https://www.terraform.io/docs/state/remote.html) tienen más información e instrucciones sobre qué hacer si quieren operar todos los integrantes del grupo sobre una misma cuenta de Azure y compartir su tfstate.

### Verificación

Una vez levantados los servidores, se puede verificar su correcto funcionamiento utilizando la URL que se encuentra dentro del archivo `lb_dns` de la carpeta `node` y pegándole:

```sh
curl `cat node/lb_dns`
```

Lo cual chequeará que la app Node funciona. A su vez, si se quiere ver que la app se puede comunicar con el servidor Python es necesario utilizar:

```sh
curl `cat node/lb_dns`/remote
```

Para verificar que la conexión de la app Node con Redis funciona, ejecutar:

```sh
curl `cat node/lb_dns`/remote/cached
```

Para limpiar el caché entre corridas:

```sh
curl `cat node/lb_dns`/remote/cached -vX DELETE
```

Pueden probar distintos escenarios de hits al caché cambiando el parámetro `cacheKeyLength` que se encuentra en `node/config.js`

### Cambio de cantidad de instancias en el VMSS de la aplicación Node

Si se cambia la cantidad de instancias en el VMSS, una vez aplicados los cambios en la infraestructura, pueden ejecutar:

```sh
ansible/deploy.sh
```

Este script actualiza el inventario con las direcciones IP de los nodos del VMSS y luego instala la aplicación Node en cada uno. Puede ejecutarse todas las veces que sea necesario (si hay nodos que ya tienen la aplicación, para éstos la ejecución será más rápida).

### Administración de la aplicación Node

El proyecto usa [pm2](https://pm2.keymetrics.io/) para daemonizar y administrar la aplicación Node. Pueden ver [aquí](https://pm2.keymetrics.io/docs/usage/quick-start/) documentación para acceder a los logs, detener y arrancar la aplicación, etc.

### Envío de métricas a Datadog

El agente de Datadog se instala en cada instancia de Node y en la de Python automáticamente, cuando ejecutan el script `start.sh`.

Para enviar métricas desde Artillery, vean la configuración [aquí](https://artillery.io/docs/guides/plugins/plugin-publish-metrics.html). Revisen el archivo `perf/run.sh` para colocar la API key en la variable `DATADOG_API_KEY`.
