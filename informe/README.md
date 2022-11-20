# Trabajo Práctico 2

En este trabajo buscamos hacer un análisis de un sistema en distintas configuraciones, intentando encontrar el cuello de botella que lo limita.

Específicamente, nuestro sistema se compone de un cluster de instancias de aplicaciones de `express` (`node.js`) que a su vez llaman a un servidor de `gunicorn` (`python`).


```bash
# Pingueamos a nuestro Azure Virtual Machine Scale Set
# Este cluster funciona como load balancer y delega el ping a alguna de las instancias de node.js
$ curl "http://ladrillo-fdm.eastus.cloudapp.azure.com"
Hello World!

# Pingueamos al VMSS, pero esta vez le pedimos a `/remote` en vez de `/`
# Este endpoint hace un llamado externo al servidor de gunicorn
$ curl "http://ladrillo-fdm.eastus.cloudapp.azure.com/remote"
{"id":1}
```

Los casos que queremos analizar son:

- ¿Qué pasa si solo tengo una instancia de `node`?
- ¿Qué pasa si el cluster, cual load balancer, llama a 3 instancias de `node`?
- ¿Qué pasa si a una única instancia de `node` le agrego una cache de `Redis`?

---

Nuestras pruebas consisten de correr el mismo escenario de `artillery` para todas las configuraciones de nuestro sistema, para así tener puntos de comparación.

```bash
# Llamamos al escenario de artillery sobre el endpoint `/remote`
# El escenario consiste de correr `ping.yaml` el cual es nada más unos llamados a `/` para ver cuanta latencia estamos manejando actualmente, y luego correr `scenario.yaml` que contiene el flujo principal de WarmUp + RampUp + Plain + CleanUp
$ cd perf
$ ./run.sh "/remote"
All VUs finished. Total time: 4 minutes, 16 seconds

--------------------------------
Summary report
--------------------------------

vusers.created: ................................................................ 700
http.requests: ................................................................. 700
http.request_rate: ............................................................. 2/sec
```

El escenario corrido finalmente impacta en Datadog, ya que todos los componentes de nuestro sistema tienen distintos agentes que reportan métricas. Es con esto que nos vamos a dar una idea de donde estan los distintos cuellos de botella que buscamos.

![Escenario de artillery a correr sobre todas las configuraciones](./img/general-scenario.png)

Para el análisis hicimos un _dashboard_, para ver como funciona y se relaciona cada componente:

![TO DO: Dashboard global del sistema](./img/general-dashboard.png)


- Localmente, nos interesan las métricas que envía `artillery`
    - Los usuarios completados y fallidos nos muestra donde esta el punto de quiebre del sistema
    - Los requests por segundo nos muestra el patrón que armó nuestro escenario
    - El tiempo de respuesta nos muestra el punto de vista del cliente, que nos sirve para compararlo con el resto del sistema
    - El número total de usuarios armados nos ayuda a confirmar que estamos efectivamente analizando un escenario entero (en vez de uno parcialmente, o el fin de uno y el comienzo de otro)
    - La latencia percibida nos da una gran idea de cuanto estamos perdiendo en el trayecto desde la computadora local hasta la instancia de la VMSS, porque surge de llamados a `/` y no a `/remote`. Es decir, al restarle este número a el tiempo de respuesta a `/remote`, podemos aproximar cuanto esta tardando la máquina de `node` en llamar a la máquina de `python`

- Luego tenemos los análisis de una de las instancias de `node`
    - El tráfico de red, el consumo de CPU y el _load average_ nos sirven para ver como esta trabajando la máquina, y así poder buscar donde esta llegando a los picos y se esta saturando.
    - El tiempo de respuesta ahora podemos verlo tambien desde el servidor, y compararlo con el punto de vista del cliente
    - TO DO: Estaria barbaro ponerle una linea en roja los 750 milisegundos. Si estas arriba de ahí, asumis que hubo llamado sin cache, si no, asumis que hubo llamado con cache.

- Un gráfico de todas los requests de todas las instancias de `node` nos muestra como esta funcionando el _load balancer_ y si alguna instancia en particular se esta saturando más que el resto.

- Finalmente tenemos los gráficos de la máquina de `gunicorn`, de la cual teóricamente no tenemos información ni acceso, pero que aun así nos es funcional al análisis
    - La "alarma todo esta bien" nos muestra que... todo esta bien. Viendo el código sabemos que todos los pedidos tienen un `sleep(0.75)`. Es por eso que este gráfico _siempre_ debe ser una línea constante de 750 milisegundos, con o sin intermitencias. Si hay algun corte significara que nunca hubo un llamado acá (lo cual nos lleva a asumir que el solicitante tenía un valor en su cache)
    - El tráfico de red y el _load average_ de esta máquina cumplen el mismo propósito de las instancias de `node`
    - Los requests recibidos nos sirven para ver si efectivamente hubo un llamado a esta máquina, o si el solicitante resolvió de otra manera el resultado (un cache)


---

TO DO: Entonces... ¿Qué pretendemos ver?

- Verde al principio, rojo despues en single
- etc etc etc

## Estudio 1 - Node Singular

![Hosts al tener solo una instancia de node](./img/1node-hosts.png)

Comenzamos el analisis ejecutando un escenario de prueba con un solo nodo. Las fases que tendra la primera prueba son inicialmente una fase de WarmUp de 60 segundos con un arrival rate de 1, luego una fase de RampUp de 60 segundos con un arrival rate inicial de 1 y un rampTo de 5, luego Plain por 60 segundos y arrival rate de 5 y finalmente una fase de CleanUp con arrival rate de 5 y rampTo de 1.

Ejecutando artillery vemos los siguientes graficos.

![grafico](img/1node-prueba1-requests.png)

En este primer grafico apreciamos la cantidad de requests por segundo que se le envian al servidor de node.

![grafico](img/1node-prueba1-users.png)

En este grafico podemos ver en verde los requests enviados que lograron completarse exitosamente, mientras que en rojo vemos aquellos requests que fallaron. Estamos en un escenario donde apenas se empiezan a aumentar la cantidad de requests por segundo, los mismos empiezan a fallar.

![grafico](img/1node-prueba1-response.png)

En este grafico podemos apreciar el tiempo de respuesta de los requests. Vemos que si bien inicialmente el tiempo se mantiene constante, en un determinado punto empieza a aumentar muy rapidamente. Este momento coincide con el momento donde se comenzaron a enviar mas requests por segundo (esto podemos constatarlo con el grafico anterior). Luego directamente el servidor deja de responder, presumiblemente por la cantidad de requests que se acumularon. Vemos que ambos graficos tienen sentido juntos.

![grafico](img/1node-prueba1-server.png)

En este grafico podemos ver el tiempo de respuesta que demora el servidor de node, y vemos como este tiempo se mantiene constante inicialmente y luego comienza a aumentar cuasi-linealmente.

Lo que podemos inferir de este primer analisis es que al enviarle una request por segundo al servidor de node todo parece funcionar bien y no hay demora en las responses. Luego, al comenzar a enviar 5 requests por segundo ya saturamos el servidor y los tiempos de response aumentan mucho. Vemos con esto que el límite de correcto funcionamiento es menor a 5 requests por segundo. Intentaremos encontrar este límite con mayor exactitud en los siguientes analisis.


Ahora repetiremos el escenario antes presentado pero en lugar de llegar a 5 requests por segundo, llegaremos a 3 requests por segundo.

![grafico](img/1node-prueba2-requests.png)

Vemos en este grafico, similar al presentado en la prueba anterior, las requests por segundo que se le envian al servidor de node.

![grafico](img/1node-prueba2-users.png)

![grafico](img/1node-prueba2-response.png)

![grafico](img/1node-prueba2-server.png)

Vemos un caso similar al anterior, donde las requests que envia el usuario inicialmente tienen resultados satisfactorios pero luego de que comienzan a aumentar las requests por segundo, el servidor cada vez tarda mas, es decir aumenta su tiempo de respuesta, y aumentan tambien la cantidad de requests fallidas.

La diferencia de este caso con el anterior es que aquí se tarda mas tiempo en saturar el servidor, producto de que redujimos la cantidad de requests por segundo. Nuevamente debemos reducir la cantidad de requests por segundo para encontrar el límite de correcto funcionamiento.

Ahora volveremos a reducir la cantidad de requests por segundo, esta vez llegaremos a 2 requests por segundo. Obtenemos los siguientes graficos que analizaremos luego de presentarlos:

![grafico](img/1node-prueba3-requests.png)

![grafico](img/1node-prueba3-users.png)

![grafico](img/1node-prueba3-response.png)

![grafico](img/1node-prueba3-server.png)

Nuevamente podemos apreciar que el servidor se satura, pero siguiendo con la tendencia del anterior experimento, vemos que tarda mas en hacerlo y que la cantidad de requests completados es aun mayor. Lo que nos esta indicando esto es que la cantidad que puede manejar una sola replica de node, sin que se vea afectada su performance, es entre 1 y 2 requests por segundo.

Logicamente no tiene sentido en la vida real decir que mandamos 1 request y fracción de otro, es decir no se pueden fraccionar los requests. Para obtener un valor exacto y que tenga sentido podriamos hablar de cada cuantos segundos mandamos un requests, ya que los segundos si podemos fraccionarlos.

## Estudio 2 - Node Replicado x3

![Hosts al tener tres instancias de node](./img/3node-hosts.png)

## Estudio 3 - Node Singular con Redis

![Hosts al tener solo una instancia de node, con cache de Redis](./img/1nodecached-hosts.png)
