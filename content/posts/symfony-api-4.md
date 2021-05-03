+++
title = "Создание API на базе Symfony 5. Часть 4. Обработка исключений"
date = "2021-05-03T13:30:50+03:00"
tags = ["php", "backend", "symfony", "api"]
+++

[Создание API на базе Symfony 5. Часть 1. Введение]({{< relref "symfony-api-1" >}})

[Создание API на базе Symfony 5. Часть 2. Подготовка окружения]({{< relref "symfony-api-2" >}})

[Создание API на базе Symfony 5. Часть 3. Начало проекта]({{< relref "symfony-api-3" >}})

## Тогда

В прошлой статье мы создали наш первый простейший роут и выучили одно из самых важных правил - любая бизнес-логика
должна быть в сервисах. Даже незначительная. По сути, весь код который вы пишете, должен располагаться в сервисах 🙂
Когда требуется обратиться к сервису, вы *открываете* до него доступ. К примеру, чтобы обратиться к нему через
**HTTP** вы пишете контроллер, чтобы вызвать его для обработки очереди rabbitmq - вы пишите воркера и т.п.

## Сейчас

В этой части мы сконцентрируемся на обработке исключений, и для этого мы добавим еще пару методов в наше API:
**получение книги по id** и **получение списка книг по id категории**.

Когда мы вызываем сервисы, они могут выбрасывать исключения и их нужно каким-то образом обрабатывать так, чтобы отдавать
пользователю адекватные сообщения об ошибках. Поскольку мы пишем API с json-форматом, то ошибки так же должны
преобразовываться в json-ответы с правильным http-кодом. Для начала займемся созданием новых моделей и сервисов а потом
рассмотрим варианты решений.

## Добавляем книги

Мы не будем делать прям реальную модель книги, потому что в этом не будет смысла для наших целей. Используя команду
`./bin/console make:entity Book` создадим следующую сущность:

```php
<?php

/**
 * @ORM\Entity(repositoryClass=BookRepository::class)
 */
class Book
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
     * @ORM\ManyToOne(targetEntity="App\Entity\Category")
     */
    private Category $category;

    /**
     * @ORM\Column(type="date", name="published_date")
     */
    private DateTimeInterface $publishedDate;

    /**
     * @ORM\Column(type="string", length=255)
     */
    private string $author;

    /**
     * @ORM\Column(type="boolean", name="is_bestseller")
     */
    private bool $isBestseller;

    /**
     * @ORM\Column(type="decimal", precision=5, scale=2)
     */
    private float $price;

    /**
     * @ORM\Column(type="string", length=255)
     */
    private string $isbn;
}
```

Здесь и далее я привожу сокращенные версии кода, полные будут доступны на github под соответствующем тэгом.

После добавления сущности, нужно сделать что? Правильно - написать сервис для работы с этой сущностью 🙂 Создаем
`BookService`, который будет реализовывать ранее оговоренное поведение:

```php
<?php

class BookService
{
    private BookRepository $bookRepository;

    private CategoryRepository $categoryRepository;

    private function mapBook(BookEntity $entity): Book
    {
        return (new Book())
            ->setId((int) $entity->getId())
            ->setTitle($entity->getTitle())
            ->setAuthor($entity->getAuthor())
            ->setIsBestseller($entity->isBestseller())
            ->setPrice($entity->getPrice())
            ->setIsbn($entity->getIsbn())
            ->setPublishedDate($entity->getPublishedDate());
    }

    public function getById(int $id): Book
    {
        $book = $this->bookRepository->find($id);
        if (null === $book) {
            throw new BookNotFoundException();
        }

        return $this->mapBook($book);
    }

    /**
     * @return Book[]
     * @psalm-return array<Book>
     */
    public function getByCategoryId(int $id): array
    {
        $category = $this->categoryRepository->find($id);
        if (null === $category) {
            throw new CategoryNotFoundException();
        }

        return array_map(
            [$this, 'mapBook'],
            $this->bookRepository->findBy(['category' => $category])
        );
    }
}
```

Сервис достаточно простой, поэтому ни реализацию контроллера ни модели я приводить я не буду. Пора заняться делом 🙂

## Первые попытки обработки исключений

Исходя из коды выше, если мы не нашли категорию или книгу мы выбрасываем исключение, но как оно будет обработано? Если
мы не указывали заголовок `Accept` при запросе, то мы увидим в ответ **html с ошибкой**. Код ответа будет **500**.
Насколько это правильно? Совсем не правильно. **500 ошибка** обозначает внутреннюю ошибку сервера, но у нас не было
никакой критической ошибки. Мы просто не нашли категорию / книгу и нам бы больше хотелось вернуть **404** с каким-нибудь
вменяемым текстом. Что делать?

Самое наивное решение было бы таким:

```php
<?php

class BookController extends AbstractController
{
    private BookService $bookService;
    
    /**
     * @Route("/api/v1/book/{id}", name="book", methods={"GET"})
     */
    public function book(int $id): Response
    {
        try {
            $books = $this->json($bookService->getById($id));
        } catch (BookNotFoundException $notFoundException) {
            throw new NotFoundHttpException('book not found', $exception);
        }
        
        return $this->json($books);
    }
}
```

Т.е. в каждом методе контроллера оборачивать вызов сервиса, ловить доменные исключения и превращать их в
http-исключения. Вроде даже выглядит не так плохо 🙂 Но, что будет если сервис сможет выкидывать не 1 исключение, а 3?
Тогда в каждом методе, где явно или не явно вызывается этот метод сервиса, мы будем вынуждены писать обработку каждого
из исключений. Плюс стандартные исключения библиотек если они используются в самом сервисе. А если у нас пачка методов,
то такой подход быстро заставит наши контроллеры значительно потолстеть. 

А почему бы не выкидывать сразу исключения унаследованные от `HttpException` типа `NotFoundHttpException` из пакета
`http-kernel`? Они как раз будут автоматически преобразованы во вменяемый ответ. Ответ простой - мы не должны путать
слои. Когда мы пишем логику в сервисах, мы вообще не должны иметь понятия как этот сервис был вызван. К примеру, что
если наш сервис был вызван из крона? Выкидывать при этом исключение http - что-то совершенно странное потому что
никакого общения по http не было 🙂

## Правильная обработка исключений в API

Более правильным вариантом является написание отдельного `слоя`, который занимается обработкой исключений и
предоставлять клиенту ошибку в интересующем его формате. Но из чего будет состоять этот слой и где он будет
располагаться? Слой будет располагаться за пределами контроллера и сервиса. Он будет отлавливать любые исключения,
которые не были пойманы. Тем самым мы сохраним сервис нетронутым, а контроллер тонким.

Чтобы это сделать, мы будем ловить события `KernelEvents::EXCEPTION` из которого мы сможем получить необработанное
исключение. Чтобы превратить его в нормальный ответ нам потребуется написать маппинги и сервис для нахождения маппинга
по исключению.

Техника достаточно старая и используется в FosRestBundle и API Platform.

Конфигурация будет достаточно простой. Для начала заведем в `config/services.yaml` параметры настройки:

```yaml
parameters:
    exceptions: 
        App\Exception\BookNotFoundException: { code: 404, hidden: false }
        App\Exception\CategoryNotFoundException: { code: 404, hidden: false }
```

Мы ограничимся 2мя исключениями, но потом добавим больше. Ключом является FQCN, а значением хэш настроек, где:

- `code` - код ответа;
- `hidden` - скрывать ли оригинальное сообщение эксепшена (по умолчанию все сообщения исключений скрываются т.е. не
отображаются клиенту);
- `loggable` - логировать ли исключение (по умолчанию исключения не логируются).

Создадим простейший класс `ExceptionMapping` для представления этих настроек:

```php
<?php

class ExceptionMapping
{
    private int $code;

    private bool $hidden;

    private bool $loggable;

    public function __construct(int $code, bool $hidden = true, bool $loggable = false)
    {
        $this->code = $code;
        $this->hidden = $hidden;
        $this->loggable = $loggable;
    }
    
    // геттеры
```

Этот класс будет использоваться в сервисе `ExceptionMappingResolver`:

```php
<?php

class ExceptionMappingResolver
{
    private array $mappings = [];

    private function addMapping(string $class, int $code, bool $hidden, bool $loggable): void
    {
        $this->mappings[$class] = new ExceptionMapping($code, $hidden, $loggable);
    }

    public function __construct(array $mappings)
    {
        foreach ($mappings as $class => $mapping) {
            if (empty($mapping['code'])) {
                throw new InvalidArgumentException('code is mandatory for class '.$class);
            }

            $this->addMapping(
                $class,
                $mapping['code'],
                $mapping['hidden'] ?? true,
                $mapping['loggable'] ?? false,
            );
        }
    }

    public function resolve(string $throwableClass): ?ExceptionMapping
    {
        $foundMapping = null;

        foreach ($this->mappings as $class => $mapping) {
            if ($throwableClass === $class || is_subclass_of($throwableClass, $class)) {
                $foundMapping = $mapping;
                break;
            }
        }

        return $foundMapping;
    }
}
```

Хотелось бы обратить ваше внимание на конструктор, из которого мы выкидываем исключение. Обычно в конструкторе не должно
быть никакой логики кроме как присвоения аргументов в поля класса, почему тогда мы кидаем исключение и используем метод
`addMapping`, хотя могли бы эту 1 строчку написать сразу в конструкторе?

Причина выбрасывания исключения - отсутствие в **php** типизированных массивов. Т.е. мы вообще ничего не знаем о
структуре массива, который нам передали. Т.е. справедливо сказать, что если нам передали не тот тип данных, который мы
ожидаем, то работать с ним не имеет смысла и выбрасывание исключения из конструктора вполне оправдано.

Метод `addMapping` был создан тоже не просто так. Он нужен по той же причине - вынося заполнение массива в отдельный
метод, мы можем проверить типы данных сразу в списке аргументов. Такой прием достаточно широко используется в исходниках
**Symfony**.

В конфигурацию сервисов необходимо добавить следующее определение:

```yaml
App\Service\System\ExceptionMappingResolver:
    arguments: ['%exceptions%']
```

Сервис получает на вход наши настройки исключений и предоставляет метод `resolve`, который находит эти настройки по
названию классу либо по его предку. Если маппинг не найден, возвращается `null`.

Окей, мы написали резолвер, но что с ним теперь делать? Как подключить и заставить работать? Для этого нам нужно
написать еще 1 класс - `ApiExceptionListener`, который будет ловить все необработанные исключения и использовать сервис,
чтобы составить правильный ответ клиенту:

```php
<?php

class ApiExceptionListener
{
    public function __invoke(ExceptionEvent $event): void
    {
        $throwable = $event->getThrowable();
        $mapping = $this->mappingResolver->resolve(\get_class($throwable));
        if (null === $mapping) {
            $mapping = new ExceptionMapping(Response::HTTP_INTERNAL_SERVER_ERROR);
        }

        if ($mapping->getCode() >= Response::HTTP_INTERNAL_SERVER_ERROR || $mapping->isLoggable()) {
            $this->logger->error($throwable->getMessage(), [
                'trace' => $throwable->getTraceAsString(),
                'previous' => null !== $throwable->getPrevious() ? $throwable->getPrevious()->getMessage() : '',
            ]);
        }

        $message = $mapping->isHidden() ? Response::$statusTexts[$mapping->getCode()] : $throwable->getMessage();
        $data = $this->serializer->serialize(new ErrorResponse($message), JsonEncoder::FORMAT);
        $response = new JsonResponse($data, $mapping->getCode(), [], true);
        $event->setResponse($response);
    }
}
```

Много кода, что здесь происходит? По умолчанию мы используем стратегию запрета с правилами исключения. Если мы не
указали настройки исключения, то ответ будет с кодом 500 и пустым телом. Далее, мы логируем исключение если код в
настройках больше или равен 500. И напоследок если мы указали в исключении содержимое сообщения и настроили его как
`hidden: false`, то это сообщение будет отображено пользователю в теле.

Дополнительно, обратить внимание стоит на `ErrorResponse` - это простейшая модель, которая содержит только 1 строковое
поле `error`. Сериализатор необходим чтобы вызывались геттеры у этой модели иначе нам бы пришлось объявить это поле
`error` как `public`.

Этому `EventListener`'у необходимо сменить приоритет чтобы он отрабатывал раньше, чем возможные остальные:

```yaml
App\EventListener\ApiExceptionListener:
    tags:
        - { name: kernel.event_listener, event: kernel.exception, priority: 10 }
```

Теперь попробуем еще раз курлануть и получим правильные 404 ошибки в json. Для простоты мы не будем рассматривать
изменение формата зависимости от `Accept` заголовка.

Казалось бы тут можно закончить, но есть еще пара не покрытых нами кейсов.

## Исключения из админки

Часто бывает, что помимо API в этом же проекте у нас может быть поднята админка типа Sonata или EasyAdmin, которые имеют
свои обработчики исключений и выводят красивые сообщения в html. Как заставить наш обработчик работать только для части
API?

Чтобы это сделать, нужно добавить еще 1 `EventListener`, но уже на каждый запрос. Он будет проверять, что путь запроса
соответствует, к примеру, пути `/api/` и записывает это в атрибуты запроса:

```php
<?php

class ZoneMatcherListener
{
    private RequestMatcherInterface $requestMatcher;

    public function __invoke(RequestEvent $event): void
    {
        $request = $event->getRequest();
        $matched = $this->requestMatcher->matches($request);

        $request->attributes->set(RequestAttributes::API_ZONE, $matched);
    }
}
```

`RequestAttributes::API_ZONE` - всего лишь константа с уникальным ключем в атрибутах.

Так же нужно отредактировать наш обработчик исключений добавив проверку на этот атрибут:

```php
$isApiZone = $event->getRequest()->attributes->get(RequestAttributes::API_ZONE, true);
if (!$isApiZone) {
    return;
}
```

И финальный штрих - передать `RequestMatcher` через конфигурацию:

```yaml
api_zone_matcher:
    class: Symfony\Component\HttpFoundation\RequestMatcher
    arguments: ['^/api/']

App\EventListener\ZoneMatcherListener:
    tags:
        - { name: kernel.event_listener, event: kernel.request, priority: 300 }
    arguments:
        - '@api_zone_matcher'
```

## В заключение

После всего этого у нас появился вполне видимый профит - наши исключения очень просто и гибко преобразовываются в
http-ответы в 1 конкретном месте. Больше не нужно писать длинные `try-catch` чтобы просто перебросить исключения.

Ранее я сказал про *пару кейсов* и не привел второй. Этот кейс - обработка исключений при валидации входящих данных. Мы
не будем его рассматривать сегодня, но обязательно вернемся к нему когда будем обрабатывать данные о заказе.

Весь код с тестами залью на днях.