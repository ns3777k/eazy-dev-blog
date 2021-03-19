+++
title = "Немного вестей из OpenSource"
date = "2021-03-14T13:13:15+03:00"
tags = ["backend", "java", "golang", "sv", "spring", "opensource"]
+++

Немного новостей из OpenSource, к которому недавно приложился:

#### Hoverfly

Теперь умеет загружать файл из внешнего источника по http и использовать его в качестве response body. Поддерживаются
так же ограничение на доверенность источника. Пример:

```json
{
  "response": {
    "status": 200,
    "encodedBody": false,
    "templated": false,
    "bodyFile": "https://raw.githubusercontent.com/SpectoLabs/hoverfly/master/schema.json"
  }
}
```

При этом **hoverfly** должен быть запущен с флагом разрешающим скачивание (по аналогии с CORS):

```shell
$ hoverfly -response-body-files-allow-origin="https://raw.githubusercontent.com/"
```

[Документация](https://docs.hoverfly.io/en/latest/pages/keyconcepts/simulations/pairs.html?highlight=bodyFile#serving-response-bodies-from-files)
[Pull Request](https://github.com/SpectoLabs/hoverfly/pull/961)

#### Spring Cloud Consul

Первый пул реквест на джаве 😱 Недавно столкнулся со следующей проблемой - был хост, на котором был запущен nginx,
consul, grafana, prometheus и т.п. Любой входящий траффик должен был проходить через nginx, соответственно, все сервисы
за nginx'ы были доступны через rewrite. Проблема появилась, когда приложение на джаве не могло подключиться к консулу не
через корень чтобы забрать настройки.

Релиза новой версии пока не было, но скоро будет 🙂

[Pull Request](https://github.com/spring-cloud/spring-cloud-consul/pull/713)
