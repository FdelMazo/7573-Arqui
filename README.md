# Trabajo Práctico 1

## Servicios

En este trabajo vamos a comparar dos servicios distintos, con los mismos endpoints. Ambos servicios se acceden a través de nginx y ambos están implementados en Node.js; su unica diferencia es que el primer servicio tiene solo un proceso, mientras que el segundo esta replicado en múltiples contenedores (configurado en 5 réplicas).

Al levantar la aplicación, tenemos a nginx corriendo en `localhost:5555`. El primer servicio esta sobre `/`, y el segundo en `/many`. Los endpoints que proveen son:

- `/ping`: Un simple healtcheck. Devuelve un número identificador del proceso, para poder confirmar que el servicio replicado esta contestando desde distintos lugares.
- `/work?n=15`: Una manera de representar cálculos pesados. Computa y devuelve los primeros n-mil dígitos de pi, siendo `n` configurable.
- `/sync`: Invoca el servicio sincrónico `bbox` (explicado más adelante)
- `/async`: Invoca el servicio asincrónico `bbox`

```zsh
$ make up # levantamos los múltiples contenedores con docker-compose
Creating network "7573-arqui_default" with the default driver
Creating 7573-arqui_grafana_1  ... done
Creating 7573-arqui_bbox_1     ... done
Creating 7573-arqui_node_1     ... done
Creating 7573-arqui_node_2     ... done
Creating 7573-arqui_node_3     ... done
Creating 7573-arqui_node_4     ... done
Creating 7573-arqui_node_5     ... done
Creating 7573-arqui_graphite_1 ... done
Creating 7573-arqui_nginx_1    ... done
Creating 7573-arqui_cadvisor_1 ... done

# Probemos ambos healthchecks
$ curl "localhost:5555/ping"
[28] pong
$ curl "localhost:5555/many/ping"
[99] pong

# Chequeemos que se contesta desde distintos procesos (por el número identificador)
$ for run in {1..7}; do curl localhost:5555/ping; done
[28] pong
[28] pong
[28] pong
[28] pong
[28] pong
[28] pong
[28] pong
$ for run in {1..7}; do curl localhost:5555/many/ping; done
[99] pong
[69] pong
[28] pong
[11] pong
[12] pong
[28] pong
[69] pong

# Testeemos todos los endpoints
$ curl "localhost:5555/work"
31415926...
$ curl "localhost:5555/sync"
Hello world!
$ curl "localhost:5555/async"
Hello world!

# Mostremos un poco cuanto trabaja el calculador de Pi
# mil digitos -> menos de un segundo
$ time curl "localhost:5555/work?n=1"
0,01s user 0,01s system 50% cpu 0,037 total
# 10 mil digitos -> menos de un segundo...
$ time curl "localhost:5555/work?n=10"
0,00s user 0,00s system 2% cpu 0,297 total
# 100 mil digitos -> veinte segundos!
$ time curl "localhost:5555/work?n=100"
0,00s user 0,00s system 0% cpu 20,632 total
```

## Performance Testing

- https://www.softwaretestingclass.com/what-is-performance-testing/
- Explicar y mostrar ejemplos de artillery
- Pelar grafos de grafana y demas
- Vista componentes y conectos
- Deberán generar sus propias métricas desde la app Node para ser enviadas al daemon de statsd. Como mínimo, deberán generar una métrica con la demora en responder de cada endpoint (vista desde Node). Este métrica deberá ser visualizada en un gráfico adicional, que estará correlacionado con los demás gráficos en el tiempo.

Se utiliza Artillery para realizar pruebas de performance sobre los endpoints del servidor. Se realizaran estas pruebas para el caso de una unica replica del servidor y para el caso donde hay 5 replicas del mismo.

La prueba para cada endpoint y para cada caso (una replica y multiples replicas) inicia en la fase de "Ramp", que dura 30 segundos, y consiste en enviar 5 requests por segundo inicialmente, pero ir aumentando la cantidad de requests por segundo hasta llegar a 30 requests por segundo. Luego de la fase de ramp, se inicia la fase "Plain" donde se mantiene una cantidad de requests por segundo constante de 30 requests por segundo durante 120 segundos. Luego de esto, se realiza una fase de "Cooldown", que dura 30 segundos, y consiste en ir disminuyendo la cantidad de requests por segundo hasta llegar a 5 requests por segundo.

## Servicio `bbox`

```
Análisis y caracterización

Deberán caracterizar cada servicio mirando tres propiedades:

    Sincrónico / Asincrónico: Uno de los servicios se comportará de manera sincrónica, y el otro de manera asincrónica. Deberán detectar de qué tipo es cada uno.
    Cantidad de workers (en el caso sincrónico): El servicio sincrónico está implementado con una cantidad de workers. Deberán buscar algún indicio sobre cuál es esta cantidad.
    Demora en responder: Cada servicio demora un tiempo en responder, que puede ser igual o distinto entre ellos. Deberán obtener este valor para cada uno.

Las herramientas para este análisis son las mismas que usaron en la Sección 1. Deben generar carga que ponga en relieve las características de cada servicio, haciendo uso de gráficos para mostrar puntos interesantes de la prueba. Incluyan en el informe una descripción de la/s estrategia/s utilizada/s. Recomendamos, por claridad, agregar una tabla al final de la sección con los resultados para cada uno.
```

## Caso de estudio: Sistema de inscripciones

¿Cómo debería comportarse un sistema de inscripciones facultativo? Hagamos un par de suposiciones, y centremonos en intentar simular un sistema de inscripciones para FIUBA.

¿Con cuanta carga estamos trabajando? Basado en algunas fuentes[^1] podemos tomar como supuestos para nuestro sistema simulado que vamos a trabajar con una carga de 10 mil alumnos. Cada uno de estos alumnos se inscribirán en entre 3 y 5 materias.

Desde el punto de vista del usuario:

- Iniciar sesión
- Seleccionar una carrera
- Inscribirse a n materias:
    - Ver la lista de materias en las que está inscripto
    - Ver la lista de materias disponibles
    - Inscribirse en una materia
- Cerrar sesión

Desde el punto de vista del sistema:

- A nuestros 10 mil alumnos los dividimos uniformemente en franjas horarias de 30 minutos (las prioridades), en una semana laboral:
    - De 9hs a 18hs de un día tenemos 18 franjas
    - De lunes a viernes tenemos 18 * 5 => 90 franjas
    - 10 mil alumnos en 90 franjas => ~100 alumnos activos en el sistema en cualquier (media) hora dada[^2]

- Asumiendo la ansiedad del alumnado, vamos a asumir que, si bien hay 30 minutos para inscribirse, la mayoría de los alumnos (75%) de una franja horaria se inscribiran en los primeros 10 minutos de la franja, y el resto lo hará mas relajadamente en lo que queda de la media hora.

Habiendo marcado todas estas suposiciones e hipótesis, lo que pretendemos ver en nuestros gráficos es un pico de _hits_ al endpoint de `/iniciar_sesion` cada media hora, y uno similar de `n` (3~5) _hits_ a `/inscribir_materia`.

<!-- Este scenario esta modelado en `perf/siu.yaml`. -->

[^1]: [Blog de Nico Paez](https://blog.nicopaez.com/2021/05/23/sobre-las-estadisticas-de-inscriptos-en-fiuba/) - [Padrón de Estudiantes Regulares 2022](https://cms.fi.uba.ar/uploads/PADRON_DEFINITIVO_ESTUDIANTES_2022_MESAS_1_429d2abc05.pdf) - [Infobae](https://www.infobae.com/educacion/2022/05/23/63-mil-anotados-al-cbc-de-la-uba-cuales-fueron-las-carreras-mas-elegidas-las-que-mas-crecieron-y-cayeron/)

[^2]: No vamos a simular alumnos entrando al sistema fuera de su franja horaria (problema conocido del SIU Guaraní)
