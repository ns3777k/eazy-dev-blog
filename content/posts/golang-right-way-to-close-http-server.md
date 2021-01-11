+++
title = "Правильное закрытие http-сервера в golang"
date = "2021-01-11T01:47:40+03:00"
tags = ["golang", "backend"]
+++

Прежде чем закрывать http-сервер, разберемся как нужно правильно закрывать приложение ☝️ К сожалению, в **golang**
многие вещи приходится писать руками и первое из этого — обработка сигналов.

## Сигналы

Сигналы это одно из средств межпроцессорного взаимодействия (IPC). К примеру, когда мы запускаем приложение и нажимаем
`Ctrl` + `C`, операционная система посылает сигнал `SIGINT` процессу с просьбой завершиться. Помимо этого сигнала, нужно
иметь в виду еще `SIGTERM`, что в принципе тоже самое, что и `SIGINT`, но отправляется **не** с терминала. Оба этих
сигнала процесс может перехватить и выполнить какие-либо действия (закрыть дескрипторы, залогировать что-то и т.д.) и
завершиться. Это называется **Graceful shutdown**. Последний важный для нас сигнал - `SIGKILL`, но его уже нельзя отловить, он убивает процесс не давая ему
времени нормально завершиться. **Kubernetes** и другие платформы отправляют сначала `SIGTERM`, ждут 10+ секунд и потом
нещадно убивают через `SIGKILL`. Бойлерплейт для ожидания сигнала в golang обычно выглядит так:

```golang
func handleSignals(cancel context.CancelFunc) {
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)

	<-c
	cancel()
}
```

На вход передается `cancel`-функция для отмены контекста **всего** приложения поле получения сигнала.

## HTTP-сервер

Создать http-сервер достаточно просто:

```golang
server := &http.Server{Addr: config.ListenAddr, Handler: h.Router}
```

Сложнее правильно его закрыть. Для начала определим функцию, которая его запустит:

```golang
func run(ctx context.Context) error {
    return server.ListenAndServe()
}
```

Казалось бы, на этом можно закончить 💪 Но нет. Эта функция работает не очень правильно, и дальше мы будем ее
прокачивать. Начнем с того, что `run` возвращает ошибку если она произошла. Но `ListenAndServe` возвращает **не nil**
даже если сервис был закрыт успешно:

```golang
func run(ctx context.Context) error {
    err := server.ListenAndServe()
    if err == http.ErrServerClosed {
		return nil
	}
    
    return err
}
```

Но как завершить сервер успешно? Программно мы **обычно** делаем только в 1 случае — когда родительский контекст
отменили (к примеру из-за сигнала). Для нашего примера, мы оставим функцию `run` блокирующей, добавим обработку отмены
и **graceful shutdown** с таймаутом для завершения всех текущих запросов:

```golang
func run(ctx context.Context) error {
    go func() {
		<-ctx.Done()

		graceCtx, graceCancel := context.WithTimeout(context.Background(), 5 * time.Second)
		defer graceCancel()

		if err := server.Shutdown(graceCtx); err != nil {
		    // log, ...
		}
	}()
    
    err := server.ListenAndServe()
    if err == http.ErrServerClosed {
		return nil
	}
    
    return err
}
```

`server.Shutdown` заставит сервер перестать принимать новые подключения и даст 5 секунд уже активным соединениям
завершиться. Здесь практически все правильно, кроме 1 детали — когда вызывается `server.Shutdown`, `server.ListenAndServe`
моментально возвращает результат. Это значит активным соединениям нужно успеть отработать до того, как мы закончим
исполнение программы. Чтобы сделать поведение более предсказуемым и стабильным, нужно добавить канал, который будет
блокировать выход из функции, пока в него что-то не запишут, а писать будем сразу после вызова `server.Shutdown`.
Финальный вид функции:

```golang
func run(ctx context.Context) error {
    httpShutdownCh := make(chan struct{})

    go func() {
		<-ctx.Done()

		graceCtx, graceCancel := context.WithTimeout(context.Background(), 5 * time.Second)
		defer graceCancel()

		if err := server.Shutdown(graceCtx); err != nil {
		    // log, ...
		}
		
		httpShutdownCh <- struct{}{}
	}()
    
    err := server.ListenAndServe()
    <-httpShutdownCh
    
    if err == http.ErrServerClosed {
		return nil
	}
    
    return err
}
```

Тип данных в канале — пустой `struct` для микро оптимизации, потому он не занимает память.
