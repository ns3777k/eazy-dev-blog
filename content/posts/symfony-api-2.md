+++
title = "Создание API на базе Symfony 5. Часть 2. Подготовка окружения"
date = "2021-01-01T20:20:50+03:00"
tags = ["php", "backend", "symfony", "api"]
+++

[Создание API на базе Symfony 5. Часть 1. Введение]({{< relref "symfony-api-1" >}})

[Создание API на базе Symfony 5. Часть 3. Начало проекта]({{< relref "symfony-api-3" >}})

## Начинаем с мелочей

Перед тем как начать что-то разрабатывать, нужно подготовить окружение. В этой части мы установим начальные зависимости,
настроим **docker-compose**, создадим конфигурации, условимся по некоторым конвенциям и т.д. Сразу оговорюсь, что я никогда
в жизни не разрабатывал на windows, только на linux или mac, поэтому какие-то вещи на винде просто тупо не взлетят.

Первое, что мы делаем при старте нового проекта, создаем [.editorconfig](https://editorconfig.org/):

```cfg
# editorconfig.org
root = true

[*]
charset = utf-8
end_of_line = LF
trim_trailing_whitespace = true
insert_final_newline = true

[*.{yml,yaml,php,html,twig,js,xml,xml.dist,json}]
indent_style = space
indent_size = 4

[{Makefile,Dockerfile}]
indent_style = tab
indent_size = 4
```

Это нужно чтобы больше никогда не путать табы с пробелами (особенно раздражает в диффе), избавиться от пробелов в конце
строк и т.д. Любая **IDE** сама настроится на корректное форматирование при присутствии этого файла (вероятно, может
потребоваться плагин). Не нужно больше договариваться с командой и рассказывать про код стайл при онбординге новых
сотрудников. Возьмем за правило автоматизировать все, что возможно ☺️ даже мелочи.

## Консистентная разработка

Установка **PHP** это достаточно большой геморой, особенно когда вам требуются разные версии языка для разных проектов
на разных операционных системах 🧐 Поэтому, мы будем использовать докер для любых телодвижений, будь то **composer** или
PHP-бинарник.

Прежде, чем мы что-то сделаем, нам понадобится утилита, которая будет хранить и запускать нужные нам команды и скрипты
из одного места. Таких есть несколько:

- **Phing** это аналог **Ant** для PHP. Раньше имел вес, но он очень устарел и практически не развивается;
- **Composer-скрипты** требуют установленного PHP, а запуск его скриптов из-под докера нам не подойдет, потому что запуск
  **docker-compose** из-под докер-контейнера имеет ряд нюансов типа проблем с монтированием;
- В нашем проекте будет использоваться классика - **make**.

Для начала нам понадобится создать файл в папке `docker/runtime/.gitignore` с содержимом - `*`, чтобы игнорировать все в
себе. Эта папка будет хранить сгенерированные, платформо-зависимые данные для работы приложения в докере. Далее, нужно
файл в корне проекта `Makefile` с небольшим бойлерплейт кодом:

```make
#
# BEGIN DEV
#

UNAME=$(shell uname)
USERID=$(shell id -u)
GROUPID=$(shell id -g)
DOCKERUSER="$(USERID):$(GROUPID)"
DOCKER_RUN_OPTS=-u $(DOCKERUSER) --rm -it
COMPOSER_IMAGE=composer:2.0.3
PHP_DEV_IMAGE=php-custom:7.4-fpm-buster

ifeq ($(UNAME), Linux)
	USERGROUP:=$(shell getent group $(GROUPID) | cut -d: -f1)
endif

ifeq ($(UNAME), Darwin)
	USERGROUP=staff
endif

.PHONE: dev-prepare-runtime
dev-prepare-runtime:
	@echo -e "Preparing runtime group and passwd files..."
	@echo "$(USER):x:$(USERID):$(GROUPID):$(USERGROUP):/home/$(USER):/bin/bash" > $(PWD)/docker/runtime/passwd
	@echo "$(USERGROUP):x:$(GROUPID):$(USER)" > $(PWD)/docker/runtime/group

.PHONY: dev-install
dev-install: dev-prepare-runtime
	@docker run $(DOCKER_RUN_OPTS) -v $(PWD):/app -v /tmp:/tmp $(COMPOSER_IMAGE) install

.PHONY: dev-composer-require
dev-composer-require:
	@docker run $(DOCKER_RUN_OPTS) -v $(PWD):/app -v /tmp:/tmp $(COMPOSER_IMAGE) require $(PACKAGE)

.PHONY: dev-composer-require-dev
dev-composer-require-dev:
	@docker run $(DOCKER_RUN_OPTS) -v $(PWD):/app -v /tmp:/tmp $(COMPOSER_IMAGE) require --dev $(PACKAGE)

.PHONY: dev-composer-update
dev-composer-update:
	@docker run $(DOCKER_RUN_OPTS) -v $(PWD):/app -v /tmp:/tmp $(COMPOSER_IMAGE) update $(PACKAGE)

.PHONY: dev-docker-build
dev-docker-build:
	@docker build -t php-custom:7.4-fpm-buster -f docker/images/Dockerfile.dev docker/images

#
# END DEV
#
```

Выглядит стремно, но здесь на самом деле все просто. Ключевое здесь - определить различные идентификаторы пользователя и
его группы, чтобы составить файлы `passwd` и `group`. Это нужно? чтобы заставить докер генерировать файлы и папки с
правами пользователя на хостевой ОС. Данный способ будет работать и для linux и для mac. Для начальной установки
зависимостей нужно будет ввести команду:

```shell
$ make dev-install
```

Следующим шагом создадим `docker/images/Dockerfile.dev`:

```dockerfile
FROM php:7.4-fpm-buster
ARG DEBIAN_FRONTEND=noninteractive
WORKDIR /project
ENV LANG=ru_RU.UTF-8 \
	LC_ALL=ru_RU.UTF-8 \
	LANGUAGE=ru_RU.UTF-8 \
	COMPOSER_ALLOW_SUPERUSER=1 \
	COMPOSER_HOME=/tmp

COPY --from=composer /usr/bin/composer /usr/bin/composer
```

Это будет образ специально для разработки. Сейчас там только **composer**, но позже мы добавим в него **xdebug** и
вероятно, какие-то еще модули. На определенном этапе нам потребуется создать образ для продакшена и тогда мы выделим
общую часть в т.н. базовый образ, чтобы избежать копипасты. Для простоты, dev-образ будет лежать рядом с проектом, но
обычно, и dev и prod и базовый уносятся в отдельный репозиторий, потому что они одинаковые для нескольких проектов.
Каждый проект может наследовать их и кастомизировать по вкусу. Соберем наш dev-образ командой:

```shell
$ make dev-docker-build
```

Последнее, что нужно сделать — написать **docker-compose** конфиг и запустить проект локально. Для старта нам будет
достаточно 2х контейнеров: **nginx** и **php-fpm**. Начнем с конфига для nginx, который поместим в `docker/build/nginx/dev/conf.d/default.conf`:

```nginx
server {
  server_name _;
  root /project/public;

  error_log /dev/stderr debug;
  access_log /dev/stdout;

  underscores_in_headers on;

  location = /favicon.ico {
    access_log /dev/null;
    empty_gif;
  }

  location / {
    try_files $uri /index.php$is_args$args;
  }

  location ~ ^/index\.php(/|$) {
    fastcgi_pass fpm:9000;
    fastcgi_split_path_info ^(.+\.php)(/.*)$;
    include fastcgi_params;

    fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
    fastcgi_param DOCUMENT_ROOT $realpath_root;
    internal;
  }

  location ~ \.php$ {
    fastcgi_pass fpm:9000;
    fastcgi_split_path_info ^(.+\.php)(/.*)$;
    include fastcgi_params;

    fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
    fastcgi_param DOCUMENT_ROOT $realpath_root;
  }
}
```

И далее в корень проекта `docker-compose.dev.yml`:

```yaml
version: '3.5'

services:

    nginx:
        image: nginx:1.15-alpine
        container_name: nginx
        ports:
            - 8080:80
        volumes:
            - "$PWD/docker/build/nginx/dev/conf.d:/etc/nginx/conf.d"
            - "$PWD:/project"
        depends_on:
            - fpm
        networks:
            - symfony-api-demo

    fpm:
        image: "$PHP_DEV_IMAGE"
        user: "$DOCKERUSER"
        container_name: fpm
        environment:
            XDEBUG_CONFIG: "remote_connect_back=1 remote_enable=1"
        volumes:
            - "$PWD/docker/runtime/passwd:/etc/passwd:ro"
            - "$PWD/docker/runtime/group:/etc/group:ro"
            - "$PWD:/project"
        networks:
            - symfony-api-demo

networks:
    symfony-api-demo:
        name: symfony-api-demo
```

Ничего необычного в конфигурации нет. И последний штрих, добавим запуск в **Makefile**:

```make
DOCKERCOMPOSE=DOCKERUSER=$(DOCKERUSER) COMPOSER_IMAGE=$(COMPOSER_IMAGE) PHP_DEV_IMAGE=$(PHP_DEV_IMAGE) docker-compose
DOCKERCOMPOSE_UP_OPTS=--force-recreate --abort-on-container-exit --build

.PHONY: dev-start
dev-start:
	@$(DOCKERCOMPOSE) -f docker-compose.dev.yml up $(DOCKERCOMPOSE_UP_OPTS)
```

В принципе все. Чтобы поднять приложение нужно запустить:

```shell
$ make dev-start
```

## Безопасность зависимостей

Библиотечные зависимости проекта тоже пишут люди, которые могут допускать ошибки. Мы никогда не можем гарантировать, что
то, что мы устанавливаем безопасно, но можем узнать о найденных уязвимостях чтобы во время обновиться. Помимо
специализированных решений типа **sonarqube**, есть 2 пути для отслеживания библиотек, которые практически не требуют
никаких настроек:

- Поскольку мы используем **Symfony** и устанавливали его через cli-утилиту, то можем позволить себе использовать
команду `symfony security:check`. Она выкачивает базу из интернета и производит проверки зависимостей локально. Есть
правда и небольшой минус, cli-утилита **не open source**. Если проект был бы не на **Symfony**, то можно было бы
заюзать [SensioLabs Security Checker](https://github.com/sensiolabs/security-checker), но он загружает лок-файл на
удаленный сервер.
- Бывают ситуации, когда вызов команды сделать невозможно. К примеру, когда ваш CI находится на сервере не имеющим
доступ к интернету или прокси позволяет ходить на конкретный список урлов. В этом случае, можно использовать
[Roave/SecurityAdvisories](https://github.com/Roave/SecurityAdvisories). Это "пустой" composer-пакет, который
прописывает все знакомые уязвимые версии в конфликтные, тем самым не позволяя их установить.

## Линтеры и статические анализаторы

Дальше, обмажемся линтерами и дополнительными инструментами и статическими анализаторами. Начнем с [php-cs-fixer](https://cs.symfony.com/):

```shell
$ make dev-composer-require-dev PACKAGE=friendsofphp/php-cs-fixer
```

Это создаст в корне проекта файл `.php_cs.dist`, который вполне ок, но давайте добавим еще 1 правило:

```php
<?php

// ...

return PhpCsFixer\Config::create()
    ->setRules([
        '@Symfony' => true,
        '@Symfony:risky' => true, // <---- добавить рискованные правильно
        'array_syntax' => ['syntax' => 'short'],
    ])
    ->setRiskyAllowed(true)  // <--- разрешить рискованные правила
    ->setFinder($finder);
```

Это позволит добавить дополнительные прикольные правила с возможностью автофикса. Рискованными они называются потому что
автофикс может изменить поведение кода, подробнее лучше посмотреть в [документации](https://cs.symfony.com/doc/rules/index.html).

Для статического анализа, в современном мире, существуют 2 утилиты: [phpstan](https://phpstan.org/) и [psalm](https://psalm.dev/).
Первый более популярный, возьмем его:

```shell
$ make dev-composer-require-dev PACKAGE="phpstan/phpstan phpstan/phpstan-symfony"
```

Для конфигурации необходимо создать в корне проекта файл `phpstan.neon` со следующим содержимым:

```yaml
parameters:
  symfony:
    container_xml_path: var/cache/dev/App_KernelDevDebugContainer.xml
  level: 8
  fileExtensions:
    - php
  paths:
    - src
    - tests
includes:
  - vendor/phpstan/phpstan-symfony/extension.neon
  - vendor/phpstan/phpstan-symfony/rules.neon
```

Как можно увидеть, мы будем проводить статический анализ по жести 🤬 Для тестов его можно, конечно, отключить, но
бывают случаи, когда он спасает (не забудьте создать папку tests до того, как линтер будет запущен, иначе будет ошибка).
Какие-то самые распространенные исключения можно внести в конфиг регуляркой.

Последний шаг, добавить вызов всех линтеров в **Makefile**:

```make
.PHONY: lint
lint:
	bin/console lint:container
	bin/console lint:yaml config/services.yaml --parse-tags
	vendor/bin/php-cs-fixer fix -v --dry-run --stop-on-violation
	vendor/bin/phpstan analyse --memory-limit=1G

.PHONY: dev-lint
dev-lint:
	@docker run $(DOCKER_RUN_OPTS) -v $(PWD):/project $(PHP_DEV_IMAGE) make lint
```

Возможно после запуска `make dev-lint`, буду ошибки, исправьте их сами.

## Установка дополнительных пакетов

Сразу установим несколько зависимостей, который нам понадобятся в следующих частях. Добавим **xdebug** в dev-образ:

```dockerfile
RUN pecl install xdebug-2.8.1 && \
    docker-php-ext-enable xdebug
```

После этого не забудьте пересобрать его. Плюс, добавим несколько базовых composer-пакетов:

```shell
$ make dev-composer-require PACKAGE="sensio/framework-extra-bundle symfony/monolog-bundle"
```

## Настройка базы данных

Мы будем использовать **postgres**. Сначала нужно поправить **Makefile**, изменив `dev-install` так, чтобы при первом
вызове создавалась папка для сохранения данных базы. Вынесем это действие в новый таргет `dev-prepare-fs`:

```make
.PHONY: dev-prepare-fs
dev-prepare-fs:
    mkdir -p $(PWD)/docker/data/postgres/data || true

.PHONY: dev-install
dev-install: dev-prepare-fs dev-prepare-runtime
    # ...
```

Перед запуском, нужно создать файл `docker/data/.gitignore` с содержимым `*`. Затем можно запускать команду:

```shell
$ make dev-prepare-fs
```

В `docker-compose.dev.yml` нужно добавить новый сервис:

```yaml
postgres:
  image: postgres:13.1-alpine
  user: "$DOCKERUSER"
  volumes:
      - "$PWD/docker/runtime/passwd:/etc/passwd:ro"
      - "$PWD/docker/runtime/group:/etc/group:ro"
      - "$PWD/docker/data/postgres/data:/var/lib/postgresql/data"
  environment:
      POSTGRES_DB: symfony-api-demo
      POSTGRES_PASSWORD: password
```

Просто добавить сервис недостаточно, нужно удостовериться, что **php-fpm** запускается строго после поднятия базы данных,
в противном случае, приложение будет падать если к нему обратится клиент в тот момент, когда база еще не поднялась, а
поднимается она достаточно времени. Даже если мы не будем обращаться к серверу, то автоматический накат миграций при
старте не будет проходить. Также, недостаточно прописать `depends_on` в определении сервиса **fpm**, потому что этот
параметр не влияет на ожидание открытия порта.

Чтобы восстановить правильный порядок запуска, необходимо добавить в образ скрипт [wait-for-it.sh](https://github.com/vishnubob/wait-for-it)
и `command` в определение сервиса **fpm**:

```yaml
command: /wait-for-it.sh postgres:5432 -t 300 -- php-fpm -F -O
```

Пока с софтом закончили, приступим к подключению **ORM** к проекту:

```shell
$ make dev-composer-require PACKAGE="symfony/orm-pack"
$ make dev-composer-require-dev PACKAGE="symfony/maker-bundle"
```

DSN подключения пропишем в `.env.local`:

```cfg
DATABASE_URL="postgresql://postgres:password@postgres:5432/symfony-api-demo?serverVersion=13&charset=utf8"
```

В `Dockerfile.dev` нужно добавить установку пакета `libpq-dev`, конфигурацию модуля `pgsql` и установку модулей
`pdo_pgsql` и `pgsql`:

```dockerfile
RUN apt-get update -y && \
    apt-get install -y libpq-dev && \
    rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql && \
    docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) pdo_pgsql pgsql
```

После этого нужно пересобрать образ и можно запустить приложение.

## Финальная проверка и резюме

На этом этапе у нас есть все необходимое окружение, чтобы начать разрабатывать приложение. Создадим тестовый контроллер
в файле `src/Controller/HelloController.php` для проверки:

```php
<?php

declare(strict_types=1);

namespace App\Controller;

use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

class HelloController
{
    /**
     * @Route("/status", name="status")
     */
    public function index(): Response
    {
        return new JsonResponse(['status' => true]);
    }
}
```

Вы должны будете увидеть ответ, если дерните [http://localhost:8080/status](http://localhost:8080/status).

Напоминалка. Весь написанный код будет расположен в [репозитории](https://github.com/ns3777k/symfony-api-demo).