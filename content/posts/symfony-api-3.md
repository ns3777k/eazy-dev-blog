+++
title = "Создание API на базе Symfony 5. Часть 3. Начало проекта"
date = "2021-01-07T01:30:50+03:00"
tags = ["php", "backend", "symfony", "api"]
+++

[Создание API на базе Symfony 5. Часть 1. Введение]({{< relref "symfony-api-1" >}})

[Создание API на базе Symfony 5. Часть 2. Подготовка окружения]({{< relref "symfony-api-2" >}})

[Создание API на базе Symfony 5. Часть 4. Обработка исключений]({{< relref "symfony-api-4" >}})

## Небольшое описание проекта

Пришла пора определиться с проектом. Мы будем разрабатывать часть API книжного магазина издательства (типа [manning](https://www.manning.com/)).
Здесь и далее листинги кода будут сокращенные (весь код доступен на [github](https://github.com/ns3777k/symfony-api-demo)). Основные сущности:

- Категория
- Книга
- Автор
- Заказ
- Оценка
- Аккаунт
- Список желаний
- Промокод
- Акция

В реализации пойдем от простого к сложному. По стэку будем использовать [postgres](https://www.postgresql.org/),
[hoverfly](https://hoverfly.io/) для эмуляции внешних сервисов, [prometheus](https://prometheus.io/) для метрик,
[grafana](https://grafana.com/) для отображения графиков по метрикам и [mailhog](https://github.com/mailhog/MailHog) для
просмотра отправленной почты.

Перед продолжением, добавим таргет, чтобы зайти в **fpm**-контейнер и запустить консольную команду:

```make
.PHONY: dev-exec-php
dev-exec-php:
	@$(DOCKERCOMPOSE) -f docker-compose.dev.yml exec fpm bash
```

## Добавление категорий

Начнем с самой простой сущности - **Категория**:

```php
<?php

/**
 * @ORM\Entity(repositoryClass=CategoryRepository::class)
 */
class Category
{
    /**
     * @ORM\Id
     * @ORM\GeneratedValue(strategy="IDENTITY")
     * @ORM\Column(type="integer")
     */
    private ?int $id;

    /**
     * @ORM\Column(type="string", length=255)
     */
    private string $title;

    /**
     * @ORM\Column(type="string", length=255)
     */
    private string $slug;

    /**
     * @ORM\Column(type="datetime", nullable=true, options={"default": "CURRENT_TIMESTAMP"})
     */
    private ?DateTimeInterface $createdAt;

    /**
     * @ORM\Column(type="datetime", nullable=true, options={"default": "CURRENT_TIMESTAMP"})
     */
    private ?DateTimeInterface $modifiedAt;
}
```

Создадим сеттеры и геттеры, миграцию и запустим ее. Стратегия **IDENTITY** используется чтобы миграция сгенерировала
поле `id` как `SERIAL`. Чтобы отдавать объекты классов в ответах контроллера, нужно добавить сериалайзер:

```shell
$ make dev-composer-require PACKAGE="symfony/serializer-pack"
```

Теперь давайте сделаем **очень наивный** контроллер, чтобы отдавать список категорий:

```php
<?php

class CategoryController extends AbstractController
{
    /**
     * @Route("/api/v1/categories", name="categories")
     */
    public function categories(CategoryRepository $categoryRepository): Response
    {
        return $this->json($categoryRepository->findAll([], ['title' => Criteria::ASC]));
    }
}
```

## Фикстуры

Код готов, но нужно добавить тестовые данные. Это должно не ручным добавлением в базу данных, а импортом фикстур через
[DoctrineFixturesBundle](https://symfony.com/doc/current/bundles/DoctrineFixturesBundle/index.html). Добавим простейшую
фикстуру:

```php
<?php

public function load(ObjectManager $manager)
{
    $category = (new Category())
        ->setTitle('Testing category')
        ->setSlug('testing-category');

    $manager->persist($category);
    $manager->flush();
}
```

Проимпортируем:

```shell
$ ./bin/console doctrine:fixtures:load --purge-with-truncate
```

И курланем роут:

```json
[
  {
    "id": 1,
    "title": "Testing category",
    "slug": "testing-category",
    "createdAt": "2021-01-05T20:21:10+00:00",
    "modifiedAt": "2021-01-05T20:21:10+00:00"
  }
]
```

## Недостатки реализации

Работает, круто. Но как я сказал, реализация **очень наивна**, но почему-то постоянно встречается в проектах. Она имеет
несколько недостатков:

1. Мы отдаем сущности базы данных напрямую клиенту, что даже звучит дико :-) Контроллер относится к слою представления, а сущность - к слою хранения. Они никогда не должны зависеть друг от друга напрямую;
2. При добавлении нового поля или изменении существующего, ответ сервиса автоматически изменится;
3. Появляется соблазн засунуть немножко логики в модель (типа trim поля или условия присваивания);
4. Со временем, модель будет обрастать аннотациями сериализации, сваггером и т.д. и вот с этого момента начнется бардак между хранением и представлением;
5. Обычным делом может стать добавление логики в контроллер, что осложнит тестирование, а переиспользование станет невозможным. Контроллеры станут толстыми.

## Рефакторинг

Возможно, недостатки не так сильно видны на таком простом примере, но давайте попробуем пойти по более правильному пути.
Первое, что нам нужно сделать — четко определить ответ роута. Это будет массив объектов, которые содержат только 3 поля:
id, заголовок и символьный код. Даты нам не нужны на стороне клиента. Такой объект часто называется моделью (в терминах
сваггера) или **DTO**, создадим **App\Model\Category**:

```php
<?php

class Category
{
    private int $id;
    private string $title;
    private string $slug;

    public function __construct(int $id, string $title, string $slug)
    {
        $this->id = $id;
        $this->title = $title;
        $this->slug = $slug;
    }

     // геттеры
}
```

Массив таких объектов будет отдавать **App\Service\CategoryService::categories**:

```php
<?php

/**
 * @return Category[]
 */
public function categories(): array
{
    return array_map(
        fn ($category) => new Category($category->getId(), $category->getTitle(), $category->getSlug()),
        $this->categoryRepository->findBy([], ['title' => Criteria::ASC])
    );
}
```

Любая логика должна располагаться **только** в сервисах.

Все остальные сервисы мы будем писать в таком же духе с перемаппингом сущностей в модели. Это может показаться излишним,
особенно для такого незначительного примера, но это поможет писать **сразу** нормально и расширяемо.

Заключительный шаг — поправить контроллер на использование сервиса вместо репозитория. Курлим для теста:

```json
[
  {
    "id": 5,
    "title": "Testing category",
    "slug": "testing-category"
  }
]
```

Отлично. Мы практически доделали наш первый роут. Нам осталось только 2 вещи чтобы полностью закончить функционал
категорий: документация и тестирование.

## Документация

Каждый роут должен сопровождаться документацией, в которой будут описаны: запрос, параметры запроса, тело ответа,
заголовки ответа, формат тела и т.д. Для описания этого всего есть спецификация [OpenAPI](https://swagger.io/specification/).
Писать ее руками и поддерживать мы, конечно же не будем, а подключим бандла [NelmioApiDocBundle](https://symfony.com/doc/current/bundles/NelmioApiDocBundle/index.html):

```shell
$ make dev-composer-require PACKAGE="nelmio/api-doc-bundle:^3.0"
```

При установке, **symfony** предложит выполнить рецепт установки, соглашаемся. Далее нам нужно аннотировать наш
контроллер определенным образом чтобы из него была правильно сгенерирована документация:

```php
<?php

class CategoryController extends AbstractController
{
    /**
     * @Route("/api/v1/categories", name="categories")
     * @SWG\Tag(name="Контент")
     * @SWG\Response(
     *     response=200,
     *     description="Отдает список категорий",
     *     @SWG\Schema(
     *         type="array",
     *         @SWG\Items(ref=@Model(type=Category::class))
     *     )
     * )
     */
    public function categories(CategoryService $categoryService): Response
    {
        return $this->json($categoryService->categories());
    }
}
```

Теперь если мы откроем роут `/api/doc.json`, то получим документацию в json-формате, которую можно скопипастить в [Swagger Editor](https://editor.swagger.io/).
Но постоянно копипастить не особо удобно, поэтому нужно добавить еще 2 пакета: `twig` и `asset`:

```shell
make dev-composer-require PACKAGE="twig asset"
```

И раскомментировать роут `app.swagger_ui`:

```yaml
app.swagger_ui:
    path: /api/doc
    methods: GET
    defaults: { _controller: nelmio_api_doc.controller.swagger_ui }
```

Теперь документация станет доступна по `/api/doc`. Нам потребуется слегка потюнить конфигурацию бандла `config/packages/nelmio_api_doc.yaml`:

```yaml
nelmio_api_doc:
  models:
    names:
      - { alias: 'Книжная категория', type: App\Model\Category }
  documentation:
    info:
      title: API книжного магазина издательства
      version: 1.0.0
  areas:
    path_patterns:
      - ^/api(?!/doc.*$)
```

Модель тоже можно снабдить дополнительными аннотациями:

```php
<?php

class Category
{
    /**
     * @SWG\Property(description="Идентификатор")
     */
    private int $id;

    /**
     * @SWG\Property(description="Название", example="Cloud Native")
     */
    private string $title;

    /**
     * @SWG\Property(description="Символьный код", example="cloud-native")
     */
    private string $slug;
}
```

## Тестирование

В этой части мы напишем только unit-тест. Нам потребуется изменить докерфайл добавив туда утилиту `unzip`, библиотеку
`libzip-dev` и php-модуль `zip`. После пересборки образа нужно добавить пакет `phpunit-bridge` из `composer`'а:

```shell
$ make dev-composer-require-dev PACKAGE="symfony/phpunit-bridge"
```

Чтобы использовать более свежую версию `phpunit`, нужно указать ее в `phpunit.xml.dist` (мы будем использовать `9.5`).
Сам `phpunit` скачается после запуска `bin/phpunit`.

Обычно, когда мы пишем тесты, мы наследуемся от `PHPUnit\Framework\TestCase`, но здесь будет создан собственный базовый
класс, чтобы в дальнейшем иметь возможность добавлять метод ко всем тестам. Пока добавим туда 1 метод:

```php
<?php

abstract class AbstractTestCase extends TestCase
{
    protected function setEntityId(object $entity, int $value): void
    {
        $class = new ReflectionClass($entity);

        $property = $class->getProperty('id');
        $property->setAccessible(true);
        $property->setValue($entity, $value);
        $property->setAccessible(false);
    }
}
```

Из названия понятно, что `setEntityId` нужен, поскольку добавлять метод `setId` в сущность является очень дурным тоном,
а в некоторых тестах должна быть возможность выставить заранее известный `id`. Напишем тест на метод `categories`:

```php
<?php

public function testCategories(): void
{
    $repository = $this->createMock(CategoryRepository::class);
    $repository->expects($this->once())
        ->method('findBy')
        ->with([], ['title' => Criteria::ASC])
        ->willReturnCallback(fn () => [$this->createCategory()]);

    $categoryService = new CategoryService($repository);
    $actualCategories = $categoryService->categories();
    $expectedCategories = [
        (new CategoryModel(1234, 'Test Category', 'test-category')),
    ];

    $this->assertEquals($expectedCategories, $actualCategories);
}
```

Для запуска тестов, нужно добавить 2 таргета в `Makefile`:

```make
.PHONY: test
test:
	bin/phpunit

.PHONY: dev-test
dev-test:
	@docker run $(DOCKER_RUN_OPTS) -v $(PWD):/project $(PHP_DEV_IMAGE) make test
```

И последний штрих. `phpstan` будет ругаться поскольку не сможет найти класс `TestCase`, поэтому в `phpstan.neon`
требуется добавить ключ `autoload_files`:

```yaml
parameters:
  # ...
  autoload_files:
    - bin/.phpunit/phpunit/vendor/autoload.php
  # ...
```

Запуск `make dev-test` должен показать, что тест успешно проходит. Напоследок пару холиварных параграфов.

## А почему мы не пишем интерфейс под сервис или репозиторий?

В гугле можно найти много статей о том, что интерфейс нужно писать везде где только можно и внедрять зависимость только
в виде интерфейса поскольку это позволит достичь слабую связанность. С этим конечно же нет смысла спорить, но нужно
всегда исходить из контекста и проекта. Если у вас небольшой проект, одна реализация интерфейса и новых реализаций не
планируется, то смысла делать интерфейс ради интерфейса очень мало. Больше времени займет придумывание имен нежели
дальнейший перевод на интерфейс. Про репозитории стоит дополнительно сказать, что в огромном количестве проектов, вторая
реализация будет еще реже, чем еще одна реализация сервиса.

Тем не менее, для всего вышесказанного есть одно стабильное исключение — библиотеки. Клиентский код **всегда** должен
работать с интерфейсами сервисов из библиотек.

## Холивар за маппинги

Есть 2 типа людей. Одни используют аннотации в коде и считают это нормой в **PHP**, другие топят за то, что это не
официальное мета-программирование и код нужно писать явно. Один аргумент можно убрать поскольку аннотации сменили
аргументы в **PHP 8**. Что из этого выбрать — дело вкуса, везде есть плюсы и минусы. Лично я использую аннотации в
проекте и **xml** в бандлах. Удобство работы для меня важнее, чем концептуальная справедливость, которая заставим
создать сотни разных конфигурационных файлов.
