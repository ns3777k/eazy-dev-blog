+++
title = "Создание API на базе Symfony 5. Часть 1. Введение"
date = "2020-12-31T15:30:20+03:00"
tags = ["php", "backend", "symfony", "api", "tutorial"]
+++

[Создание API на базе Symfony 5. Часть 2. Подготовка окружения]({{< relref "symfony-api-2" >}})

[Создание API на базе Symfony 5. Часть 3. Начало проекта]({{< relref "symfony-api-3" >}})

[Создание API на базе Symfony 5. Часть 4. Обработка исключений]({{< relref "symfony-api-4" >}})

## Введение

Проведя более сотни собеседований на разные должности связанные с php, стало понятно, что очень малое кол-во кандидатов
понимают как писать API для долгосрочного проекта, чья поддержка будет длиться годами. Типичные ошибки:

- Отсутствие сервисного слоя;
- Отсутствие централизованной обработки исключений;
- Отдача сущностей напрямую клиенту;
- Толстые контроллеры;
- Отсутствие тестов (или присутствие только юнитов);
- И т.д.

Поэтому я решил начать небольшой цикл статей по созданию API на фреймворке **Symfony**. Первая часть будет больше
введением.

## Выбор решения

Если погуглить, то можно найти только 2 готовых решения, которые обеспечивают инфраструктуру для построения API:

1. [FOSRestBundle](https://github.com/FriendsOfSymfony/FOSRestBundle) - проект достаточно старый и слабо поддерживается
в последнее время. Я бы не стал его использовать для новых проектов, потому что он может быть блокером, к примеру, для
обновления фреймворка.

2. [Api Platform](https://api-platform.com/) - а это уже проект достаточно новый, хотя сообщество вокруг него не большое,
но проект многообещающий. Тем не менее, мы не будем его использовать по нескольким причинам:
   - **Symfony** уже позволяет писать API без дополнительного фреймворка;
   - Дополнительная технология это всегда риск, нужно понимать как это готовить, плюсы, минусы, ...;
   - **Symfony** не самый лёгкий фреймворк, использовать поверх него еще 1 фреймворк здорово повышает порог вхождения;
   - Установка **Api Platform** добавит новую основополагающую зависимость, за которой нужно следить, обновлять и
     надеяться, что ее не задепрекейтят через пару-тройку лет.

Дополнительно стоит указать, что инфраструктурная часть API во многом похожа в этих 2х проектах. В целом, я не против
**Api Platform**, но при разработке большого и долгосрочного проекта, нужен человек, у которого есть достаточно опыта
работы с ним. Мне будет намного спокойнее работать с **Symfony** как он есть, потому что его поддержка и сообщество в
десятки раз больше этих проектов.

## Что будем делать

Мы пойдем по пути написания своего небольшого инфраструктурного "слоя" для решения, обозначенных в начале статьи,
ошибок. В конце у нас получится бойлерплейт, который можно будет кастомизировать как захочется и он не будет блокером к
обновлению фреймворка. Мы не будем полностью изобретать велосипеды, а будем использовать подходы из обоих упомянутых
решений. Мы не будем использовать DDD в полной мере, но какие-то концепции, мы естественно, от туда утащим.

Чтобы было веселее, придумаем несколько задач и усложнений, которые позволят нам увидеть, как наш бойлерплейт поможет
решить рутинные задачи при создании API. Ориентироваться будем на самый настоящий продакшен и будем учитывать метрики,
логи, тесты, докер, линтеры, пайплайны и т.д.

## Почему Symfony?

Вкусовщина, но из отличительных преимуществ среди других:

- Отсутствие **Active Record** в пользу **Data Mapper** от **Doctrine**; 
- Выбор между микро-ядром и полноценным с поддержкой шаблонов и т.д.;
- Очень гибкая архитектура;
- Авторы фреймворка создали кучу независимых компонентов, которые используются в других фреймворках;
- Отличная документация;
- Бандлы.

## Перед началом

Сначала решим одну из самых сложных задач в программировании — придумаем названием проекта.

Использовать будем **Symfony 5.2** и **PHP 7.4**. [Установить](https://symfony.com/doc/current/setup.html) проще через
[cli-утилиту symfony](https://symfony.com/download), там будет команда, чтобы поднять проект без использования
веб-сервера.

```shell
$ symfony new symfony-api-demo
* Creating a new Symfony project with Composer
  (running /usr/local/bin/composer create-project symfony/skeleton /.../ns3777k/symfony-api-demo  --no-interaction)

* Setting up the project under Git version control
  (running git init /.../ns3777k/symfony-api-demo)

                                                                                                                        
 [OK] Your project is now ready in /.../ns3777k/symfony-api-demo
```

Запустить проект можно будет командой `symfony serve` и главная страница будет доступна по адресу [http://127.0.0.1:8000](http://127.0.0.1:8000).

Весь написанный код будет расположен в [репозитории](https://github.com/ns3777k/symfony-api-demo) чтобы не приводить
полные листинги кода. Каждый этап будет отмечен тегом.
