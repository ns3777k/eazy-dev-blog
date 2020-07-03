+++
title = "Nodejs и docker pid 1"
date = "2020-07-03T21:03:50+03:00"
tags = ["frontend", "backend", "nodejs", "docker", "linux"]
+++

Удивительно, но очень многие люди, особенно фронты, до сих не знают, как правильно писать `Dockerfile` для
**nodejs**-приложений и поэтому сегодня затронем `ENTRYPOINT`.

Сначала немного теории. Есть такая штука в линуксе, как [init-процесс](https://en.wikipedia.org/wiki/Init) - это процесс,
который стартует первым и его идентификатор = 1. На такой процесс возлагаются дополнительные требования помимо запуска
дочерних приложений, а именно:

- проброс `ENV`-переменных дочерним процессам;
- обработка или делегирование системных сигналов дочерним процессам;
- предотвращение появление [zombie-процессов](https://en.wikipedia.org/wiki/Zombie_process);
- корректное завершение [orphan-процессов](https://en.wikipedia.org/wiki/Orphan_process);
- частая хотелка - рестарт дочернего процесса при падении.

`Init`-процесс указывается в `Dockerfile` командой `ENTRYPOINT`. Обычной практикой во фронте является написание чего-то
типа такого: `ENTRYPOINT ["npm", "start"]`. **npm не является** корректным `init`-процессом, хотя он умеет пробрасывать
`ENV`-переменные. К примеру, [он делегирует только](https://github.com/npm/npm-lifecycle/blob/v3.1.5/index.js#L343)
`SIGTERM` и `SIGINT`.

Следующий частый вариант, это использовать ноду в качестве `init`-процесса и с этим связано много забавных случаев по
всему интернету, особенно при использовании в `kubernetes`. Дело в том, что в большинстве случаев мы не пишем кастомную
обработку сигналов и когда такие сигналы приходят, они тупо игнорируются. Если запустить простейший http-сервер в докере
с `ENTRYPOINT ["node", "index"]` и послать сигнал `SIGTERM`, то он будет проигнорирован и ничего не произойдет. Можно,
конечно, запустить с опцией `--init`, но такое не прокатит в `kubernetes`. На самом деле, это не столько связано с нодой,
сколько с [самим linux](https://docs.docker.com/engine/reference/run/#foreground):

```
A process running as PID 1 inside a container is treated specially by Linux: it ignores any signal
with the default action. As a result, the process will not terminate on SIGINT or SIGTERM unless
it is coded to do so.
```

Чтобы процесс начал отвечать на сигналы, можно явно ему об этом сказать, добавив обработчики:

```javascript
process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
``` 

В принципе, вариант ок, но [официальная позиция](https://github.com/nodejs/docker-node/blob/master/docs/BestPractices.md#handling-kernel-signals)
такова, что **nodejs не задумывался** как `pid 1` процесс и его использование в таком виде может иметь неожиданное
поведение.

*Правильным* и *консистентным* вариантом является запуск корректного `init`-процесса, который в свою очередь, запустит
**nodejs** процесс. Таким процессом может быть, к примеру, [tini](https://github.com/krallin/tini) или
[dumb-init](https://github.com/Yelp/dumb-init). 

Я несколько раз упомянул про `kubernetes`. Суть в том, что перед тем, как он посылает `SIGKILL`, он дает приложению
выполнить `graceful shutdown` отправляя заранее `SIGTERM`. Если приложение не обрабатывает этот сигнал, то оно будет
жестко убито, а в логах будут ошибки.
